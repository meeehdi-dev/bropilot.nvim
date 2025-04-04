local ns_id = vim.api.nvim_create_namespace("bropilot")
local extmark_id = -1

local function clear()
  if extmark_id ~= -1 then
    vim.api.nvim_buf_del_extmark(0, ns_id, extmark_id)
    extmark_id = -1
  end
end

---@param lines string[]
---@param col number
local function render(lines, col)
  clear()

  if #lines == 0 then
    return
  end

  local extmark_opts = {
    virt_text_pos = "inline",
    virt_text = { { lines[1], "Comment" } },
  }

  if #lines > 1 then
    local virt_lines = {}
    for k, v in ipairs(lines) do
      if k > 1 and (k ~= #lines or v ~= "") then -- skip first line, and last line if empty
        table.insert(virt_lines, { { v, "Comment" } })
      end
    end
    extmark_opts.virt_lines = virt_lines
  end

  local line = vim.fn.line(".")
  local current_line = vim.api.nvim_get_current_line()
  local col_count = #current_line
  if col > col_count + 1 then
    col = col_count + 1
  end
  extmark_id =
    vim.api.nvim_buf_set_extmark(0, ns_id, line - 1, col - 1, extmark_opts)
end

return {
  clear = clear,
  render = render,
}
