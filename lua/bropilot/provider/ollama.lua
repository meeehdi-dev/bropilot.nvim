local util = require("bropilot.util")
local options = require("bropilot.options")
local llm_ls = require("bropilot.llm-ls")

---@type number | nil
local current_suggestion_rid = nil
---@type table<number, {progress: ProgressHandle}>
local current_suggestion_handles = {}

---@type boolean
local ready = false
---@type boolean
local initializing = false
local function is_ready()
  return not initializing and ready
end

---@type vim.lsp.Client
local llmls = nil

local bro_group = vim.api.nvim_create_augroup("bropilot-ollama", {})

---@type fun() | nil
local init_callback = nil
local function init(cb)
  local opts = options.get()

  init_callback = cb
  if ready or initializing then
    return
  end
  initializing = true

  llm_ls.init(function(cmd)
    vim.lsp.config("llm", {
      cmd = cmd,
      init_options = {
        provider = "ollama",
        params = {
          url = opts.ollama_url,
          model = opts.model,
          model_params = opts.model_params,
        },
      },
      on_init = function(client)
        llmls = client

        vim.api.nvim_create_autocmd({ "BufEnter" }, {
          group = bro_group,
          callback = function(ev)
            llmls:on_attach(ev.buf)
          end,
        })

        ready = true
        initializing = false

        if init_callback then
          init_callback()
        end
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
---@param invoked boolean
local function generate(cb, invoked)
  local suggestion_progress_handle = util.get_progress_handle("Suggesting...")
  local position_params = vim.lsp.util.make_position_params(0, "utf-16")
  if invoked then
    position_params.context = { triggerKind = 1 }
  else
    position_params.context = { triggerKind = 2 }
  end
  local success, request_id = llmls:request(
    "textDocument/inlineCompletion",
    position_params,
    function(err, res)
      vim.notify("request " .. (current_suggestion_rid or "nil") .. " finished")
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

        if #res.items > 0 then
          cb(false, res.items[1].insertText)
        end
      end
    end
  )
  if success and request_id ~= nil then
    vim.notify("request " .. request_id .. " started")
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
