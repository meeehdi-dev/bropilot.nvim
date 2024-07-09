local progress = require("fidget.progress")

local M = {}
---@return number row, number col Row index & Col index of cursor in current window
function M.get_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1], cursor[2]
end

---@param row number
---@param col number
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

---@param start number
---@param end_ number | nil
---@return string[]
function M.get_lines(start, end_)
  if end_ == nil then
    end_ = vim.api.nvim_buf_line_count(0)
  end
  return vim.api.nvim_buf_get_lines(0, start, end_, true)
end

---@param start number
---@param end_ number
---@param lines string[]
function M.set_lines(start, end_, lines)
  vim.api.nvim_buf_set_lines(0, start, end_, true, lines)
end

---@param array string[]
---@param separator string | nil
---@return string
function M.join(array, separator)
  if separator == nil then
    separator = "\n"
  end
  return table.concat(array, separator)
end

---@param text string
---@return string
local function get_last_char(text)
  return string.sub(text, #text, #text)
end

---@param text string
function M.trim(text)
  local last_char = get_last_char(text)
  while last_char == " " or last_char == "\t" or last_char == "\n" do
    text = string.sub(text, 1, #text - 1)
    last_char = get_last_char(text)
  end
  return text
end

---@return number, number
function M.get_pos()
  return vim.fn.line(".") - 1, vim.fn.col(".") - 1
end

---@param title string
function M.get_progress_handle(title)
  return progress.handle.create({
    title = title,
    lsp_client = { name = "bropilot" },
  })
end

---@param handle unknown
function M.finish_progress(handle)
  if handle ~= nil then
    handle:finish()
  end
end

---@return boolean
function M.is_mode_insert_or_replace()
  local mode = vim.api.nvim_get_mode()
  if mode.mode == "i" or mode.mode == "r" then
    return true
  end

  return false
end

---@return boolean
function M.is_buf_ready()
  local buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(buf)

  return buf_name ~= ""
end

return M
