local progress = require("fidget.progress")

local M = {}

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

return M
