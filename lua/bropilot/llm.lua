local provider = require("bropilot.provider")

---@param prefix string
---@param suffix string
---@param num_ctx number
---@return { prefix: string, suffix: string }
local function truncate(prefix, suffix, num_ctx)
  local prefix_lines = vim.split(prefix, "\n")
  local suffix_lines = vim.split(suffix, "\n")

  local current_line = prefix_lines[#prefix_lines]

  local ctx_size = 3 + #current_line / 4 -- fim tokens

  prefix = current_line
  suffix = suffix_lines[1]

  local prefix_idx = 1
  local suffix_idx = 2
  local ctx_inc = true
  while ctx_inc do
    ctx_inc = false

    local prefix_line = prefix_lines[#prefix_lines - prefix_idx]
    if prefix_line ~= nil then
      local prefix_size = #prefix_line / 4 -- tokenize ~4chars/tok
      if ctx_size + prefix_size < num_ctx then
        prefix = prefix_line .. "\n" .. prefix
        prefix_idx = prefix_idx + 1
        ctx_size = ctx_size + prefix_size
        ctx_inc = true
      end
    end

    local suffix_line = suffix_lines[suffix_idx]
    if suffix_line ~= nil then
      local suffix_size = #suffix_line / 4 -- tokenize ~4chars/tok
      if ctx_size + suffix_size < num_ctx then
        suffix = suffix .. "\n" .. suffix_line
        suffix_idx = suffix_idx + 1
        ctx_size = ctx_size + suffix_size
        ctx_inc = true
      end
    end
  end

  return { prefix = prefix, suffix = suffix }
end

---@param pid number | nil
local function cancel(pid)
  return provider.get().cancel(pid)
end

---@param before string
---@param after string
---@param cb function
local function generate(before, after, cb)
  return provider.get().generate(before, after, cb)
end

local function is_ready()
  return provider.get().is_ready()
end

---@param cb fun() | nil
local function init(cb)
  return provider.get().init(cb)
end

return {
  generate = generate,
  cancel = cancel,
  is_ready = is_ready,
  init = init,
  truncate = truncate,
}
