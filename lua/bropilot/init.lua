local curl = require("plenary.curl")
local async = require("plenary.async")
local llm = require("bropilot.llm")
local util = require("bropilot.util")

local M = {}

---@type Options
M.opts = {
  model = "codegemma:2b-code",
  prompt = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  debounce = 1000,
  auto_pull = true,
}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  callback = function()
    local row = util.get_cursor()
    local context_row = llm.get_context_row()

    if row == context_row then
      local current_line = util.get_lines(row - 1, row)[1]
      local context_line = llm.get_context_line()

      local current_suggestion = llm.get_suggestion()
      local suggestion_lines = vim.split(current_suggestion, "\n")

      local current_line_contains_suggestion = string.find(
        vim.pesc(context_line .. suggestion_lines[1]),
        vim.pesc(current_line)
      )

      if current_line_contains_suggestion then
        llm.render_suggestion()
        return
      end
    end

    llm.cancel()
    llm.clear()

    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    llm.cancel()
    llm.clear()
  end,
})

M.accept_word = llm.accept_word
M.accept_line = llm.accept_line
M.accept_block = llm.accept_block

---@param opts Options
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  -- setup options (model, prompt, keep_alive, params, etc...)
  llm.init(M.opts, function()
    local mode = vim.api.nvim_get_mode()

    if mode == "i" or mode == "r" then
      llm.suggest()
    end
  end)

  vim.api.nvim_create_user_command("Bro", function(params)
    local cmd = params.fargs[1]
    if cmd == "describe" then
      local lines = util.get_lines(params.line1 - 1, params.line2)
      local code = util.join(lines, "\n")

      local float_buf_id = vim.api.nvim_create_buf(false, true)
      local win_width = vim.api.nvim_win_get_width(0)
      local win_height = vim.api.nvim_win_get_height(0)

      local float_win_id = vim.api.nvim_open_win(float_buf_id, false, {
        relative = "win",
        win = 0,
        row = math.floor(win_height / 2 - 10),
        col = math.floor(win_width / 4),
        width = math.ceil(win_width / 2),
        border = "single",
        height = 20,
        focusable = false,
        style = "minimal",
        noautocmd = true,
      })
      vim.api.nvim_set_current_win(float_win_id)
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
      local text = ""

      curl.post("http://localhost:11434/api/generate", {
        body = vim.json.encode({
          model = "llama3:8b",
          prompt = "Describe the following code:\n```"
            .. filetype
            .. "\n"
            .. code
            .. "\n```",
        }),
        callback = function()
          -- util.finish_progress(describe_progress_handle)
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
            local body = vim.json.decode(data)
            text = text .. (body.response or "")

            vim.api.nvim_buf_set_lines(
              float_buf_id,
              0,
              -1,
              true,
              vim.split(text, "\n")
            )
          end)
        end,
      })
    end
  end, {
    nargs = 1,
    range = true,
    complete = function()
      return { "describe", "refactor", "comment", "chat", "commit" }
    end,
  })
end

return M
