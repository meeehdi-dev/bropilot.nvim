local has_progress, progress = pcall(require, "fidget.progress")

local M = {}

function M.get_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1], cursor[2]
end

function M.get_context()
  local cursor_line = M.get_cursor()

  local prefix =
    table.concat(vim.api.nvim_buf_get_lines(0, 0, cursor_line, true), "\n")
  local suffix = table.concat(
    vim.api.nvim_buf_get_lines(
      0,
      cursor_line,
      vim.api.nvim_buf_line_count(0),
      true
    ),
    "\n"
  )

  return prefix, suffix
end

function M.get_pos()
  return vim.fn.line(".") - 1, vim.fn.col(".") - 1
end

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

return M
