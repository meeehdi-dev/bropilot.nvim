local llm = require("bropilot.llm")
local util = require("bropilot.util")

local M = {}

---@type Options
M.opts = {
  model = "codellama",
  variant = "7b-code",
  debounce = 100,
}

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  callback = function()
    local row = util.get_cursor()
    local current_line = vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
    local context_line = llm.get_context_line()

    local current_suggestion = llm.get_suggestion()
    local suggestion_lines = vim.split(current_suggestion, "\n")

    -- FIXME: can possibly be simplified
    local has_suggestion = #current_suggestion > 0 and #suggestion_lines > 0
    local partially_accepted_suggestion = has_suggestion
      and context_line == ""
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

    llm.suggest(M.opts.model, M.opts.variant, current_line)
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

  -- setup options (model, prompt, keep_alive, params, etc...)
  llm.init(M.opts)
end

return M
