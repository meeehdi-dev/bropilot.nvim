local progress = require("fidget.progress")

---@param row number
---@param col number
local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

---@param start number
---@param end_ number | nil
---@return string[]
local function get_lines(start, end_)
  if end_ == nil then
    end_ = vim.api.nvim_buf_line_count(0)
  end
  return vim.api.nvim_buf_get_lines(0, start, end_, true)
end

---@param start number
---@param end_ number
---@param lines string[]
local function set_lines(start, end_, lines)
  vim.api.nvim_buf_set_lines(0, start, end_, true, lines)
end

---@param array string[]
---@param separator string | nil
---@return string
local function join(array, separator)
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
local function trim(text)
  local last_char = get_last_char(text)
  while last_char == " " or last_char == "\t" or last_char == "\n" do
    text = string.sub(text, 1, #text - 1)
    last_char = get_last_char(text)
  end
  return text
end

---@param title string
---@return ProgressHandle
local function get_progress_handle(title)
  return progress.handle.create({
    title = title,
    lsp_client = { name = "bropilot" },
  })
end

---@param handle unknown
local function finish_progress(handle)
  if handle ~= nil then
    handle:finish()
  end
end

---@param tbl string[]
---@param x string
local function contains(tbl, x)
  for _, v in pairs(tbl) do
    if v == x then
      return true
    end
  end
  return false
end

return {
  finish_progress = finish_progress,
  get_last_char = get_last_char,
  get_lines = get_lines,
  get_progress_handle = get_progress_handle,
  join = join,
  set_cursor = set_cursor,
  set_lines = set_lines,
  trim = trim,
  contains = contains,
}
