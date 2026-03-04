local util = require("bropilot.util")
local llm_ls = require("bropilot.llm-ls")

local M = {}

---@param provider_name string
---@param get_init_options fun(): table
---@return Provider
function M.create(provider_name, get_init_options)
  ---@type number | nil
  local current_suggestion_rid = nil
  ---@type table<number, {progress: ProgressHandle}>
  local current_suggestion_handles = {}

  ---@type boolean
  local ready = false
  ---@type boolean
  local initializing = false
  ---@type fun()[]
  local init_callbacks = {}

  local function is_ready()
    return not initializing and ready
  end

  ---@type vim.lsp.Client | nil
  local llmls = nil

  local bro_group =
    vim.api.nvim_create_augroup("bropilot-" .. provider_name, {})

  ---@param cb fun() | nil
  local function init(cb)
    if cb then
      table.insert(init_callbacks, cb)
    end

    if ready then
      for _, callback in ipairs(init_callbacks) do
        callback()
      end
      init_callbacks = {}
      return
    end

    if initializing then
      return
    end
    initializing = true

    llm_ls.init(function(cmd)
      vim.lsp.config("llm", {
        cmd = cmd,
        init_options = get_init_options(),
        on_init = function(client)
          llmls = client

          vim.api.nvim_create_autocmd({ "BufEnter" }, {
            group = bro_group,
            callback = function(ev)
              local buftype = vim.bo[ev.buf].buftype
              if buftype ~= "" then
                return
              end

              local filetype = vim.bo[ev.buf].filetype
              local opts = require("bropilot.options").get()
              if util.contains(opts.excluded_filetypes, filetype) then
                return
              end

              vim.lsp.buf_attach_client(ev.buf, llmls.id)
            end,
          })

          ready = true
          initializing = false

          for _, callback in ipairs(init_callbacks) do
            callback()
          end
          init_callbacks = {}
        end,
        on_exit = function()
          ready = false
          initializing = false
          llmls = nil
        end,
      })
      vim.lsp.enable("llm")
    end)
  end

  ---@param rid number | nil
  local function cancel(rid)
    if rid == nil then
      if current_suggestion_rid ~= nil then
        cancel(current_suggestion_rid)
      end
      return
    end

    if rid and current_suggestion_handles[rid] then
      local progress = current_suggestion_handles[rid].progress

      if llmls ~= nil then
        llmls:cancel_request(rid)
      end

      util.finish_progress(progress)
      current_suggestion_rid = nil
    end
  end

  ---@param cb fun(done: boolean, response?: string)
  ---@param invoked boolean | nil
  local function generate(cb, invoked)
    local suggestion_progress_handle = util.get_progress_handle("Suggesting...")
    local position_params = vim.lsp.util.make_position_params(0, "utf-16")
    if invoked then
      position_params.context = { triggerKind = 1 }
    else
      position_params.context = { triggerKind = 2 }
    end

    if llmls == nil then
      util.finish_progress(suggestion_progress_handle)
      return
    end

    local success, request_id = llmls:request(
      "textDocument/inlineCompletion",
      position_params,
      function(err, res)
        util.finish_progress(suggestion_progress_handle)
        if err then
          vim.notify(err.message, vim.log.levels.ERROR)
          return
        end

        if
          current_suggestion_rid
          and current_suggestion_handles[current_suggestion_rid]
        then
          current_suggestion_handles[current_suggestion_rid] = nil

          if res and res.items and #res.items > 0 then
            cb(false, res.items[1].insertText)
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

  return {
    cancel = cancel,
    generate = generate,
    is_ready = is_ready,
    init = init,
  }
end

return M
