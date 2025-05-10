local util = require("bropilot.util")
local handlers = require("bropilot.provider.copilot.handlers")
local _ = require("fidget.progress") -- progress handle type

---@type boolean
local ready = false
---@type boolean
local initializing = false
---@type number | nil
local current_suggestion_rid = nil
---@type number | nil
local next_suggestion_rid = nil
---@type table<number, {progress: ProgressHandle, items: any[]}>
local current_suggestion_handles = {}
---@type table<number, {progress: ProgressHandle, items: any[]}>
local next_suggestion_handles = {}
---@type vim.lsp.Client | nil
local copilot = nil

local ns_id = vim.api.nvim_create_namespace("bropilot-next")
local extmark_ids = {}

local function sign_in(err, res, ctx)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if res.status == "AlreadySignedIn" then
    vim.notify("Already logged in as " .. res.user, vim.log.levels.INFO)
  end

  if res.status == "SignedOut" then
    if copilot == nil then
      vim.notify("copilot lsp client not active", vim.log.levels.ERROR)
      return
    end

    local float_buf_id = vim.api.nvim_create_buf(false, true)

    local lines = {
      "[Copilot] Please paste this code in your browser to sign in:",
      res.userCode,
      "(press y to copy to your clipboard)",
    }
    local max_len = 0
    for _, line in ipairs(lines) do
      local len = #line
      if len > max_len then
        max_len = len
      end
    end
    for i, line in ipairs(lines) do
      local len = #line
      if len < max_len then
        lines[i] = string.rep(" ", (max_len - len) / 2) .. line
      end
    end

    vim.api.nvim_buf_set_lines(float_buf_id, 0, -1, true, lines)

    local win_id = vim.api.nvim_get_current_win()
    local win_width = vim.api.nvim_win_get_width(win_id)
    local win_height = vim.api.nvim_win_get_height(win_id)

    local float_win_id = vim.api.nvim_open_win(float_buf_id, false, {
      relative = "win",
      win = win_id,
      row = win_height / 2 - 1,
      col = win_width / 2 - math.floor(max_len / 2),
      width = max_len,
      height = 3,
      style = "minimal",
      noautocmd = true,
    })

    vim.cmd.redraw()
    -- wait for a valid input
    local c = vim.fn.getchar()
    while type(c) ~= "number" do
      c = vim.fn.getchar()
    end
    local resp = (vim.fn.nr2char(c) or ""):upper()
    if resp == "y" then
      vim.fn.setreg("*", res.userCode) -- copy code to system clipboard
    end

    vim.api.nvim_win_close(float_win_id, true)
    vim.api.nvim_buf_delete(float_buf_id, { force = true })

    copilot:exec_cmd(res.command, nil, function(cmd_err, cmd_res)
      if cmd_err then
        vim.notify(cmd_err.message, vim.log.levels.ERROR)
        return
      end
      if res.status == "loggedIn" then
        vim.notify(
          "Successfully logged in as " .. cmd_res.user,
          vim.log.levels.INFO
        )
      end
    end)
  end
end

local function clear()
  for _, extmark_id in ipairs(extmark_ids) do
    vim.api.nvim_buf_del_extmark(0, ns_id, extmark_id)
  end
  extmark_ids = {}
end

local function is_ready()
  return not initializing and ready
end

---@type fun() | nil
local init_callback = nil
---@param cb fun() | nil
local function init(cb)
  init_callback = cb
  if ready or initializing then
    return
  end
  initializing = true
  vim.lsp.start({
    name = "copilot",
    cmd = { "copilot-language-server", "--stdio" },
    init_options = {
      editorInfo = {
        name = "neovim",
        version = "0.11.0",
      },
      editorPluginInfo = {
        name = "bropilot.nvim",
        version = "1.0.0",
      },
    },
    settings = {
      nextEditSuggestions = {
        enabled = true,
      },
      telemetry = {
        telemetryLevel = "off",
      },
    },
    handlers = setmetatable({}, {
      __index = function(_, method)
        if method == "signIn" then
          return sign_in
        end
        if handlers[method] then
          return handlers[method]
        end
        vim.print("handler not found: " .. method)
      end,
    }),
    on_init = function(client)
      copilot = client

      copilot:request("signIn", vim.empty_dict())

      ready = true
      initializing = false

      if init_callback then
        init_callback()
      end
    end,
  })
end

---@param rid number | nil
local function cancel(rid)
  clear()

  if rid == nil then
    if current_suggestion_rid ~= nil then
      cancel(current_suggestion_rid)
    end
    if next_suggestion_rid ~= nil then
      cancel(next_suggestion_rid)
    end
    return
  end

  if rid and current_suggestion_handles[rid] then
    local progress = current_suggestion_handles[rid].progress

    if copilot ~= nil then
      copilot:cancel_request(rid)
    end
    util.finish_progress(progress)

    current_suggestion_rid = nil
  end
  if rid and next_suggestion_handles[rid] then
    local progress = next_suggestion_handles[rid].progress

    if copilot ~= nil then
      copilot:cancel_request(rid)
    end
    util.finish_progress(progress)

    next_suggestion_rid = nil
  end
end

local function generate_next()
  if copilot == nil then
    vim.notify("copilot lsp client not active", vim.log.levels.ERROR)
    return
  end

  local suggestion_progress_handle =
    util.get_progress_handle("Suggesting next...")
  local position_params = vim.lsp.util.make_position_params(0, "utf-16")
  position_params.context = { triggerKind = 2 }
  position_params.textDocument.version =
    vim.lsp.util.buf_versions[vim.api.nvim_get_current_buf()]
  local success, request_id = copilot:request(
    "textDocument/copilotInlineEdit",
    position_params,
    function(err, res)
      util.finish_progress(suggestion_progress_handle)
      if err then
        vim.notify(err.message, vim.log.levels.ERROR)
        return
      end
      if #res.edits > 0 then
        if
          next_suggestion_rid
          and next_suggestion_handles[next_suggestion_rid]
        then
          next_suggestion_handles[next_suggestion_rid].items = res.edits
          table.insert(
            extmark_ids,
            vim.api.nvim_buf_set_extmark(
              0,
              ns_id,
              res.edits[1].range.start.line,
              res.edits[1].range.start.character,
              {
                end_line = res.edits[1].range["end"].line,
                end_col = res.edits[1].range["end"].character,
                hl_group = "DiffDelete",
              }
            )
          )
          local lines = vim.split(res.edits[1].text, "\n")
          for k, line in ipairs(lines) do
            local extmark_opts = {
              virt_text_pos = "inline",
              virt_text = { { line, "DiffAdd" } },
            }
            local current_line_idx = res.edits[1].range["start"].line + k - 1
            local current_line =
              util.get_lines(current_line_idx, current_line_idx + 1)[1]
            local len = #current_line
            if k == 1 and current_line == res.edits[1].range["end"].line then
              len = res.edits[1].range["end"].character
            end
            table.insert(
              extmark_ids,
              vim.api.nvim_buf_set_extmark(
                0,
                ns_id,
                current_line_idx,
                len,
                extmark_opts
              )
            )
          end
        end
      else
        if
          next_suggestion_rid
          and next_suggestion_handles[next_suggestion_rid]
        then
          next_suggestion_handles[next_suggestion_rid] = nil
        end
      end
    end
  )

  if success and request_id ~= nil then
    next_suggestion_rid = request_id
    next_suggestion_handles[next_suggestion_rid] = {
      progress = suggestion_progress_handle,
    }
  end
end

---@param before string
---@param after string
---@param cb fun(done: boolean, response?: string)
local function generate(before, after, cb)
  if copilot == nil then
    vim.notify("copilot lsp client not active", vim.log.levels.ERROR)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local suggestion_progress_handle = util.get_progress_handle("Suggesting...")
  local position_params = vim.lsp.util.make_position_params(0, "utf-16")
  if string.sub(position_params.textDocument.uri, 1, 7) ~= "file://" then
    return
  end
  position_params.context = { triggerKind = 2 }
  local success, request_id = copilot:request(
    "textDocument/inlineCompletion",
    position_params,
    function(err, res)
      util.finish_progress(suggestion_progress_handle)
      if err then
        vim.notify(err.message, vim.log.levels.ERROR)
        return
      end
      if #res.items > 0 then
        local current_line = util.get_lines(row, row + 1)[1]
        cb(
          false,
          string.sub(
            res.items[1].insertText,
            col + 1,
            col + #res.items[1].insertText - #current_line
          )
        ) -- remove start of line bc copilot sends the whole line + truncate end of line if in the middle
        if
          current_suggestion_rid
          and current_suggestion_handles[current_suggestion_rid]
        then
          current_suggestion_handles[current_suggestion_rid].items = res.items
          copilot:notify(
            "textDocument/didShowCompletion",
            { item = res.items[1] }
          )
        end
      else
        if
          current_suggestion_rid
          and current_suggestion_handles[current_suggestion_rid]
        then
          current_suggestion_handles[current_suggestion_rid] = nil
        end
      end
    end
  )
  if success and request_id ~= nil then
    current_suggestion_rid = request_id
    current_suggestion_handles[current_suggestion_rid] = {
      progress = suggestion_progress_handle,
    }
  end
end

local function accept(suggestion_left)
  if copilot == nil then
    vim.notify("copilot lsp client not active", vim.log.levels.ERROR)
    return
  end

  if
    current_suggestion_rid
    and current_suggestion_handles[current_suggestion_rid]
  then
    local items = current_suggestion_handles[current_suggestion_rid].items
    local accepted_length = #items[1].insertText - #suggestion_left
    if accepted_length == #items[1].insertText then
      copilot:exec_cmd(items[1].command, nil, function(err)
        if err ~= nil then
          vim.notify(err.message, vim.log.levels.ERROR)
          return
        end
        generate_next()
      end)
      current_suggestion_rid = nil
    else
      copilot:notify("textDocument/didPartiallyAcceptCompletion", {
        item = items[1],
        acceptedLength = accepted_length,
      })
    end

    return true
  end

  return false
end

local function accept_next()
  if copilot == nil then
    vim.notify("copilot lsp client not active", vim.log.levels.ERROR)
    return
  end

  if next_suggestion_rid and next_suggestion_handles[next_suggestion_rid] then
    local items = next_suggestion_handles[next_suggestion_rid].items
    local start_line = items[1].range.start.line
    local end_line = items[1].range["end"].line
    local lines = util.get_lines(start_line + 1, end_line)
    if #lines == 0 then
      lines = { "" }
    end
    for i = 1, end_line - start_line + 1 do
      if i > start_line and i < end_line then
        table.remove(lines, i)
        i = i - 1
      else
        if i == start_line then
          lines[i] = string.sub(lines[i], 0, items[1].range.start.character)
        end
        if i == end_line then
          lines[i] = string.sub(lines[i], 0, items[1].range.start.character)
        end
      end
    end
    lines[1] = lines[1] .. items[1].text
    lines = vim.split(util.join(lines, "\n"), "\n")
    util.set_lines(start_line, end_line + 1, lines)
    util.set_cursor(start_line + #lines, #lines[#lines])
    clear()

    copilot:exec_cmd(items[1].command)
    next_suggestion_rid = nil
    generate_next()
    return true
  end

  return false
end

return {
  cancel = cancel,
  generate = generate,
  generate_next = generate_next,
  is_ready = is_ready,
  init = init,
  accept = accept,
  accept_next = accept_next,
}
