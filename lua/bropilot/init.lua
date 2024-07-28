local suggestion = require("bropilot.suggestion")
local ollama = require("bropilot.ollama")
local keymap = require("bropilot.keymap")
local options = require("bropilot.options")

local M = {}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    suggestion.get()
  end,
})

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  callback = function()
    if suggestion.contains_context() then
      suggestion.render()
      return
    end

    suggestion.cancel()
    suggestion.get()
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    suggestion.cancel()
  end,
})

local function init_keymaps()
  local opts = options.get()

  keymap.set(opts.keymap.accept_word, suggestion.accept_word)
  keymap.set(opts.keymap.accept_line, suggestion.accept_line)
  keymap.set(opts.keymap.accept_block, suggestion.accept_block)
  keymap.set(opts.keymap.resuggest, function()
    suggestion.cancel()
    suggestion.get()
    return true
  end)
end

---@param opts Options
function M.setup(opts)
  options.set(opts)
  init_keymaps()
  ollama.init()
end

return M
