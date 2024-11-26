local suggestion = require("bropilot.suggestion")
local keymap = require("bropilot.keymap")
local options = require("bropilot.options")
local ollama = require("bropilot.ollama")
local util = require("bropilot.util")

---@param opts BroOptions
local function setup(opts)
  opts = options.set(opts)
  if not opts then
    return
  end
  keymap.init()
  ollama.init()

  if opts.auto_suggest then
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
      callback = function()
        if not util.contains(opts.excluded_filetypes, vim.bo.filetype) then
          suggestion.get()
        end
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
      if
        opts.auto_suggest
        and not util.contains(opts.excluded_filetypes, vim.bo.filetype)
      then
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
