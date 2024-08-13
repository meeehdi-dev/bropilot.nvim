local suggestion = require("bropilot.suggestion")
local ollama = require("bropilot.ollama")
local keymap = require("bropilot.keymap")
local options = require("bropilot.options")

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

---@param opts Options
local function setup(opts)
  options.set(opts)
  keymap.init()
  ollama.init()
end

return {
  setup = setup
}
