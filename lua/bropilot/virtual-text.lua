local util = require("bropilot.util")

local M = {}

local ns_id = vim.api.nvim_create_namespace("bropilot")
local extmark_id = -1

---@param lines string[]
function M.render(lines)
  M.clear()

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
      if k > 1 and (k ~= #lines or v ~= "") then -- skip first line, and last line if empty
        table.insert(virt_lines, { { v, "Comment" } })
      end
    end
    extmark_opts.virt_lines = virt_lines
  end

  extmark_id = vim.api.nvim_buf_set_extmark(
    0,
    ns_id,
    vim.fn.line(".") - 1,
    #vim.api.nvim_get_current_line(),
    extmark_opts
  )
end

function M.clear()
  if extmark_id ~= -1 then
    vim.api.nvim_buf_del_extmark(0, ns_id, extmark_id)
    extmark_id = -1
  end
end

return M
