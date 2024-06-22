local llm = require("bropilot.llm")
local util = require("bropilot.util")
local keymap = require("bropilot.keymap")

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
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
  },
}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    local row, col = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]

    if col < #current_line then
      return
    end

    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  callback = function()
    local row, col = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]

    if col < #current_line then
      return
    end

    local context_row = llm.get_context_row()

    if row == context_row then
      local context_line = llm.get_context_line()

      local current_suggestion = llm.get_suggestion()
      local suggestion_lines = vim.split(current_suggestion, "\n")

      local current_line_contains_suggestion = context_line .. suggestion_lines[1] == current_line or string.find(
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

---@param opts Options
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  keymap.set(M.opts.keymap.accept_word, llm.accept_word)
  keymap.set(M.opts.keymap.accept_line, llm.accept_line)
  keymap.set(M.opts.keymap.accept_block, llm.accept_block)

  -- setup options (model, prompt, keep_alive, params, etc...)
  llm.init(M.opts, function()
    local mode = vim.api.nvim_get_mode()

    if mode == "i" or mode == "r" then
      llm.suggest()
    end
  end)
end

return M
