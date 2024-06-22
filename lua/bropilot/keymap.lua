local M = {}

---@param keycode string | nil
---@param cb function
M.set = function(keycode, cb)
  if keycode == nil or keycode == "" then
    return
  end

  vim.keymap.set("i", keycode, function()
    if cb() then
      return
    end
    local keys = vim.api.nvim_replace_termcodes(keycode, true, false, true)
    vim.api.nvim_feedkeys(keys, "n", true)
  end, { noremap = true })
end

return M
