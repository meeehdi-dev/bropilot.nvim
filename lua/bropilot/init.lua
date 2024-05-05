local llm = require("bropilot.llm")
local util = require("bropilot.util")

local M = {}

M.opts = {
  autosuggest = true,
}

vim.api.nvim_create_autocmd({ "TextChangedI" }, {
  callback = function()
    local row = util.get_cursor()
    local current_line = vim.api.nvim_buf_get_lines(0, row - 1, row, true)
    local context_line = llm.get_context_line()

    local current_suggestion = llm.get_suggestion()
    local suggestion_lines = {}
    if current_suggestion ~= "" then
      suggestion_lines = vim.split(current_suggestion, "\n")
    end

    if
      #suggestion_lines > 0
        and ((context_line == "" and suggestion_lines[1] == "")
      or (
        context_line ~= ""
        and #current_line[1] >= #context_line
        and string.find(context_line .. suggestion_lines[1], current_line[1])
      ))
    then
      llm.render_suggestion()
      return
    end

    llm.cancel()
    llm.clear(true)

    local prefix, suffix = util.get_context()

    llm.suggest(prefix, suffix, current_line[1])
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    llm.cancel()
    llm.clear(true)
  end,
})

M.accept_line = llm.accept_line
M.accept_suggestion = llm.accept_block

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  -- llm.init(opts) -- setup options (model, prompt, keep_alive, params, etc...)
  llm.preload_model()
end

return M
