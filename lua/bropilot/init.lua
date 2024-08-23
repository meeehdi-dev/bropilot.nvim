local suggestion = require("bropilot.suggestion")
local keymap = require("bropilot.keymap")
local options = require("bropilot.options")

---@param opts Options
local function setup(opts)
  opts = options.set(opts)
  keymap.init()

  if opts.auto_suggest then
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
      callback = function()
        suggestion.get()
      end,
    })
  end

  vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
    callback = function()
      if suggestion.contains_context() then
        suggestion.render()
        return
      end

      suggestion.cancel()
      if opts.auto_suggest then
        suggestion.get()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    callback = function()
      suggestion.cancel()
    end,
  })
end

return {
  setup = setup,
}
