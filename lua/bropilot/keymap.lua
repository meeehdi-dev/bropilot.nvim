local options = require("bropilot.options")
local suggestion = require("bropilot.suggestion")

---@param keycode string | nil
---@param cb fun(): boolean
---@param mode string | string[] | nil
local function set(keycode, cb, mode)
  if not keycode then
    return
  end

  if not mode then
    mode = "i"
  end

  vim.keymap.set(mode, keycode, function()
    -- if the callback already handled the keymap
    if cb() then
      return
    end

    -- else we fallback on vim default action
    local keys = vim.api.nvim_replace_termcodes(keycode, true, false, true)
    vim.api.nvim_feedkeys(keys, "n", true)
  end, { noremap = true })
end

local function init()
  local opts = options.get()

  set(opts.keymap.accept_word, suggestion.accept_word)
  set(opts.keymap.accept_line, suggestion.accept_line)
  set(opts.keymap.accept_block, suggestion.accept_block, {"i" | "n"})
  set(opts.keymap.suggest, function()
    suggestion.cancel()
    suggestion.get()
    return true
  end)
  set(opts.keymap.suggest_next, function()
    suggestion.cancel()
    suggestion.get_next()
    return true
  end, { "i", "n" })
end

return {
  init = init,
}
