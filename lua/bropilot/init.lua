local llm = require("bropilot.llm")
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
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    resuggest = "<C-Down>",
  },
  ollama_url = "http://localhost:11434/api"
}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  callback = function()
    if llm.suggestion_contains_context() then
      llm.render_suggestion()
      return
    end

    llm.cancel()
    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    llm.cancel()
  end,
})

---@param opts Options
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  keymap.set(M.opts.keymap.accept_word, llm.accept_word)
  keymap.set(M.opts.keymap.accept_line, llm.accept_line)
  keymap.set(M.opts.keymap.accept_block, llm.accept_block)
  keymap.set(M.opts.keymap.resuggest, function()
    llm.cancel()
    llm.suggest()
    return true
  end)

  llm.init(M.opts, function()
    llm.suggest()
  end)
end

return M
