local M = {}

M.set = function(keycode, callback)
  vim.keymap.set("i", keycode, function()
    if callback() then
      return
    end
    local keys = vim.api.nvim_replace_termcodes(keycode, true, false, true)
    vim.api.nvim_feedkeys(keys, "n", true)
  end, { noremap = true })
end

return M
