local suggestion = require("bropilot.suggestion")
local keymap = require("bropilot.keymap")
local options = require("bropilot.options")
local util = require("bropilot.util")

local bro_group = vim.api.nvim_create_augroup("bropilot", {})

---@param opts BroOptions
local function setup(opts)
  local ok = options.set(opts)
  if not ok then
    vim.notify("invalid bropilot configuration", vim.log.levels.ERROR)
    return
  end

  local bro_opts = options.get()
  keymap.init()

  if bro_opts.auto_suggest then
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
      group = bro_group,
      callback = function()
        if not util.contains(bro_opts.excluded_filetypes, vim.bo.filetype) then
          suggestion.get()
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd({ "TextChangedI" }, {
    group = bro_group,
    callback = function()
      if suggestion.contains_context(true) then
        suggestion.render()
        return
      end

      suggestion.cancel()
      if
        bro_opts.auto_suggest
        and not util.contains(bro_opts.excluded_filetypes, vim.bo.filetype)
      then
        suggestion.get()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMovedI" }, {
    group = bro_group,
    callback = function()
      if suggestion.contains_context(false) then
        suggestion.render()
        return
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = bro_group,
    callback = function()
      suggestion.cancel()
    end,
  })
end

return {
  setup = setup,
}
