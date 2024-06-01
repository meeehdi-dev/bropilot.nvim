local has_progress, progress = pcall(require, "fidget.progress")

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

---@param array string []
---@param separator string | nil
---@return string
function M.join(array, separator)
  if separator == nil then
    separator = "\n"
  end
  return table.concat(array, separator)
end

---@return string, string
function M.get_context()
  local cursor_line = M.get_cursor()

  local prefix = M.join(M.get_lines(0, cursor_line))
  local suffix = M.join(M.get_lines(cursor_line))

  return prefix, suffix
end

---@return number, number
function M.get_pos()
  return vim.fn.line(".") - 1, vim.fn.col(".") - 1
end

---@param title string
function M.get_progress_handle(title)
  if not has_progress then
    vim.notify("Bropilot: " .. title, vim.log.levels.INFO)
    return nil
  end
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

local ns_id = vim.api.nvim_create_namespace("bropilot")
local extmark_id = -1
---@param lines string[]
function M.render_virtual_text(lines)
  M.clear_virtual_text()

  if #lines == 0 then
    return
  end

  local extmark_opts = {
    virt_text_pos = "overlay",
    virt_text = { { lines[1], "Comment" } },
  }

  if #lines > 1 then
    local virt_lines = {}
    for k, v in ipairs(lines) do
      if k > 1 then -- skip first line
        table.insert(virt_lines, { { v, "Comment" } })
      end
    end
    extmark_opts.virt_lines = virt_lines
  end

  local line, col = M.get_pos()

  extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, line, col, extmark_opts)
end

function M.clear_virtual_text()
  if extmark_id ~= -1 then
    vim.api.nvim_buf_del_extmark(0, ns_id, extmark_id)
    extmark_id = -1
  end
end

---@param v any
function M.log(v)
  vim.print(vim.inspect(v))
end

return M
