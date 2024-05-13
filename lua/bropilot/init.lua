local llm = require("bropilot.llm")
local util = require("bropilot.util")

local M = {}

---@type Options
M.opts = {
  model = "codellama:7b-code",
  debounce = 100,
  auto_pull = true,
}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "CursorMovedI" }, {
  callback = function()
    llm.cancel()
    llm.clear(true)

    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "TextChangedI" }, {
  callback = function()
    local row = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]
    local context_line = llm.get_context_line()

    local current_suggestion = llm.get_suggestion()
    local suggestion_lines = vim.split(current_suggestion, "\n")

    -- FIXME: can possibly be simplified
    local has_suggestion = current_suggestion ~= "" and #suggestion_lines > 0
    local partially_accepted_suggestion = has_suggestion
      and context_line == ""
      and suggestion_lines[1] == ""
    -- TODO: handle partial block accept but this feels wrong...
    local partially_accepted_block = partially_accepted_suggestion
      and suggestion_lines[1] == ""
    local context_contains_suggestion = has_suggestion
      and context_line ~= ""
      and #current_line >= #context_line
      and string.find(
        context_line .. suggestion_lines[1],
        vim.pesc(current_line)
      )

    if partially_accepted_suggestion or context_contains_suggestion then
      llm.render_suggestion()
      return
    end

    llm.cancel()
    llm.clear(true)

    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    llm.cancel()
    llm.clear(true)
  end,
})

M.accept_word = llm.accept_word
M.accept_line = llm.accept_line
M.accept_block = llm.accept_block

---@param opts Options
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  -- setup options (model, prompt, keep_alive, params, etc...)
  llm.init(M.opts)
end

return M
