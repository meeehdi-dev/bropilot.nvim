local curl = require("plenary.curl")
local async = require("plenary.async")
local util = require("bropilot.util")
local virtual_text = require("bropilot.virtual-text")

---@type job | nil
local suggestion_job = nil
---@type string
local suggestion = ""
---@type string
local context_line = ""
local context_row = -1
local suggestion_progress_handle = nil
---@type boolean
local ready = false
---@type boolean
local initializing = false
---@type uv_timer_t | nil
local debounce_timer = nil

---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: number[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number }
---@alias ModelPrompt { prefix: string, suffix: string, middle: string }
---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, resuggest: string }
---@alias Options { model: string, model_params?: ModelParams, prompt: ModelPrompt, debounce: number, auto_pull: boolean, keymap: KeymapParams, ollama_url: string }

local M = {}

---@param prefix string
---@param suffix string
---@return string
local get_prompt = function(prefix, suffix)
  return M.opts.prompt.prefix
    .. prefix
    .. M.opts.prompt.suffix
    .. suffix
    .. M.opts.prompt.middle
end

---@param data string
local function on_suggestion_data(data)
  if data == nil or type(data) ~= "string" then
    return
  end

  local success, body = pcall(vim.json.decode, data)
  if not success then
    util.finish_progress(suggestion_progress_handle)
    return
  end
  if body.done then
    util.finish_progress(suggestion_progress_handle)
    return
  end

  suggestion = suggestion .. (body.response or "")

  local eot_placeholder = "<EOT>"
  local _, eot = string.find(suggestion, eot_placeholder)
  if eot then
    M.cancel()
    suggestion = string.sub(suggestion, 0, eot - #eot_placeholder)
  end

  M.render_suggestion()
end

local function do_suggest()
  local row = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]

  local cursor_line = util.get_cursor()

  local prefix = util.join(util.get_lines(0, cursor_line))
  local suffix = util.join(util.get_lines(cursor_line))

  context_line = current_line
  context_row = row
  suggestion_progress_handle = util.get_progress_handle("Suggesting...")
  suggestion_job = curl.post(M.opts.ollama_url .. "/generate", {
    body = vim.json.encode({
      model = M.opts.model,
      options = M.opts.model_params,
      prompt = get_prompt(prefix, suffix),
    }),
    callback = function(data)
      util.finish_progress(suggestion_progress_handle)
      local success, body = pcall(vim.json.decode, data.body)
      if success and body.error then
        vim.notify(body.error, vim.log.levels.ERROR)
      end
      -- else this means we force-cancelled suggestion
    end,
    on_error = function(err)
      if err.code ~= nil then
        vim.notify(err.message)
      end
    end,
    stream = function(err, data)
      async.util.scheduler(function()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
        on_suggestion_data(data)
      end)
    end,
  })
end

function M.cancel()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
  if suggestion_job then
    suggestion_job:shutdown()
    suggestion_job = nil
  end
  util.finish_progress(suggestion_progress_handle)
  suggestion = ""
  virtual_text.clear()
end

---@param model string
---@param cb function
local function find_model(model, cb)
  local find_progress_handle =
    util.get_progress_handle("Checking model " .. model)
  local check_job = curl.get(M.opts.ollama_url .. "/tags", {
    callback = function(data)
      async.util.scheduler(function()
        util.finish_progress(find_progress_handle)
        local body = vim.json.decode(data.body)
        for _, v in ipairs(body.models) do
          if v.name == model then
            cb(true)
            return
          end
        end
        cb(false)
      end)
    end,
  })
  check_job:start()
end

---@param model string
---@param cb function
local function preload_model(model, cb)
  local preload_progress_handle =
    util.get_progress_handle("Preloading " .. model)
  local preload_job = curl.post(M.opts.ollama_url .. "/generate", {
    body = vim.json.encode({
      model = model,
      keep_alive = "10m",
    }),
    callback = function()
      async.util.scheduler(function()
        if preload_progress_handle ~= nil then
          preload_progress_handle:finish()
          preload_progress_handle = nil
        else
          vim.notify(
            "Preloaded model " .. model .. " successfully!",
            vim.log.levels.INFO
          )
        end
        ready = true
        initializing = false
        cb()
      end)
    end,
  })
  preload_job:start()
end

---@param model string
---@param cb function
local function pull_model(model, cb)
  local pull_progress_handle =
    util.get_progress_handle("Pulling model " .. model)
  local pull_job = curl.post(M.opts.ollama_url .. "/pull", {
    body = vim.json.encode({ name = model }),
    callback = function()
      async.util.scheduler(function()
        util.finish_progress(pull_progress_handle)
      end)
    end,
    stream = function(err, data)
      async.util.scheduler(function()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
        local body = vim.json.decode(data)
        if pull_progress_handle ~= nil then
          if body.error then
            vim.notify(body.error, vim.log.levels.ERROR)
            util.finish_progress(pull_progress_handle)
          elseif body.status == "success" then
            util.finish_progress(pull_progress_handle)
            cb()
          else
            local report = { message = "", percentage = 100 }
            if body.status then
              report.message = body.status
            end
            if body.completed ~= nil and body.total ~= nil then
              report.percentage = body.completed / body.total * 100
            end
            pull_progress_handle:report(report)
          end
        else
          if body.error then
            vim.notify(body.error, vim.log.levels.ERROR)
          elseif body.status == "success" then
            vim.notify(
              "Pulled model " .. model .. " successfully!",
              vim.log.levels.INFO
            )
            cb()
          else
            local report = { message = "", percentage = 100 }
            if body.status then
              report.message = body.status
            end
            if body.completed ~= nil and body.total ~= nil then
              report.percentage = body.completed / body.total * 100
            end
            vim.notify(
              "Pulling model: "
                .. report.message
                .. " ("
                .. report.percentage
                .. "%)",
              vim.log.levels.INFO
            )
          end
        end
      end)
    end,
  })
  pull_job:start()
end

---@param init_options Options
---@param cb function
function M.init(init_options, cb)
  if ready or initializing then
    return
  end
  initializing = true
  M.opts = init_options
  find_model(M.opts.model, function(found)
    if found then
      preload_model(M.opts.model, cb)
    else
      if M.opts.auto_pull then
        pull_model(M.opts.model, function()
          preload_model(M.opts.model, cb)
        end)
      else
        vim.notify(M.opts.model .. " not found", vim.log.levels.ERROR)
      end
    end
  end)
end

function M.render_suggestion()
  if suggestion == "" then
    virtual_text.clear()
    return
  end

  local suggestion_lines = vim.split(suggestion, "\n")

  local row, col = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]

  if col < #current_line then
    return
  end

  local _, end_ = string.find(
    vim.pesc(context_line .. suggestion_lines[1]),
    vim.pesc(current_line)
  )
  if end_ ~= nil then
    suggestion_lines[1] =
      string.sub(context_line .. suggestion_lines[1], end_ + 1)
  end

  virtual_text.render(suggestion_lines)
end

---@return boolean
local function can_suggest()
  local mode = vim.api.nvim_get_mode()
  local mode_ok = false
  if mode.mode == "i" or mode.mode == "r" then
    mode_ok = true
  end

  local buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(buf)
  local buf_ok = buf_name ~= ""

  return mode_ok and buf_ok
end

function M.suggest()
  if not can_suggest() then
    return
  end

  if not ready then
    M.init(M.opts, function()
      if not can_suggest() then
        return
      end

      M.suggest()
    end)
    return
  end

  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  local timer = vim.uv.new_timer()
  if
    timer:start(M.opts.debounce, 0, function()
      debounce_timer = nil
      async.util.scheduler(function()
        do_suggest()
      end)
    end) == 0
  then
    debounce_timer = timer
  end
end

---@return boolean
function M.suggestion_contains_context()
  local row = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]

  local suggestion_lines = vim.split(suggestion, "\n")

  return context_line .. suggestion_lines[1] == current_line
    or string.find(
        vim.pesc(context_line .. suggestion_lines[1]),
        vim.pesc(current_line)
      )
      ~= nil
end

---@return boolean
function M.is_context_row(row)
  return row == context_row
end

---@return boolean success true if successful
function M.accept_word()
  if suggestion == "" then
    return false
  end

  local suggestion_lines = vim.split(suggestion, "\n")

  local next_lines = {}

  local row, col = util.get_cursor()
  if suggestion_lines[1] == "" then
    context_line = ""
    context_row = context_row + 1
    table.remove(suggestion_lines, 1)

    table.insert(next_lines, util.get_lines(row - 1, row)[1])
    col = 1
  end

  local current_suggestion = context_line .. suggestion_lines[1]

  local _, word_end = string.find(current_suggestion, "[^%s]%s", col + 1)
  if word_end ~= nil then
    suggestion_lines[1] = string.sub(current_suggestion, word_end)

    current_suggestion = string.sub(current_suggestion, 1, word_end - 1)
  end
  if word_end == nil then
    suggestion_lines[1] = ""
  end

  context_line = current_suggestion

  table.insert(next_lines, current_suggestion)

  util.set_lines(row - 1, row, next_lines)
  util.set_cursor(row + #next_lines - 1, #current_suggestion)

  suggestion = util.join(suggestion_lines, "\n")

  return true
end

---@return boolean success true if successful
function M.accept_line()
  if suggestion == "" then
    return false
  end

  local suggestion_lines = vim.split(suggestion, "\n")

  local row = util.get_cursor()

  local next_lines = {}

  if suggestion_lines[1] == "" then
    context_line = ""
    context_row = context_row + 1
    table.remove(suggestion_lines, 1)

    table.insert(next_lines, util.get_lines(row - 1, row)[1])
  end

  context_line = context_line .. suggestion_lines[1]
  table.insert(next_lines, context_line)

  util.set_lines(row - 1, row, next_lines)
  util.set_cursor(row + #next_lines - 1, #context_line)

  suggestion_lines[1] = ""
  suggestion = util.join(suggestion_lines, "\n")

  return true
end

---@return boolean success true if successful
function M.accept_block()
  if suggestion == "" then
    return false
  end

  local row, cursor_col = util.get_cursor()

  local next_lines = {}

  local blocks = vim.split(suggestion, "\n\n")
  if blocks[1] == "" then
    context_line = ""
    context_row = context_row + 2
    table.remove(blocks, 1)
    table.insert(next_lines, 1, util.get_lines(row - 1, row)[1])
    table.insert(next_lines, 2, "")
  end

  local line = util.get_lines(row - 1, row)[1]
  local col = string.find(line, "[^%s]") or cursor_col
  local block = blocks[1]
  local next = 2
  while
    blocks[next] ~= nil
    and blocks[next] ~= ""
    and string.find(blocks[next], "%s", col) == 1
  do
    block = block .. "\n\n" .. blocks[next]
    next = next + 1
  end

  local block_lines = vim.split(block, "\n")
  block_lines[1] = context_line .. block_lines[1]

  for k, v in pairs(next_lines) do
    table.insert(block_lines, k, v)
  end

  util.set_lines(row - 1, row, block_lines)
  util.set_cursor(row - 1 + #block_lines, #block_lines[#block_lines])

  suggestion = string.sub(suggestion, #block + #next_lines + 1)
  context_line = block_lines[#block_lines]
  context_row = row - 1 + #block_lines

  return true
end

return M
