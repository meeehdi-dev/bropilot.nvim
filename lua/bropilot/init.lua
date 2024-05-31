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
  llm.init(M.opts, llm.suggest) -- FIXME: llm.suggest should prolly be called separately only if in insert mode depending on lazy setup
end

return M
