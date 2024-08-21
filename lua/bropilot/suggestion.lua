local async = require("plenary.async")
local util = require("bropilot.util")
local virtual_text = require("bropilot.virtual-text")
local ollama = require("bropilot.ollama")
local options = require("bropilot.options")

---@type string
local current_suggestion = ""
---@type string
local context_line = ""
local context_row = -1
---@type uv_timer_t | nil
local debounce_timer = nil

local function cancel()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
  ollama.cancel()
  current_suggestion = ""
  virtual_text.clear()
end

local function render()
  if current_suggestion == "" then
    virtual_text.clear()
    return
  end

  local suggestion_lines = vim.split(current_suggestion, "\n")

  local _, end_ = string.find(
    context_line .. suggestion_lines[1],
    vim.pesc(vim.api.nvim_get_current_line())
  )
  if end_ ~= nil then
    suggestion_lines[1] =
      string.sub(context_line .. suggestion_lines[1], end_ + 1)
  end

  virtual_text.render(suggestion_lines)
end

---@param done boolean
---@param response string
local function on_data(done, response)
  if done then
    return
  end

  if response then
    current_suggestion = current_suggestion .. response
  end

  local eot_placeholder = "<EOT>"
  local _, eot = string.find(current_suggestion, eot_placeholder)
  if eot then
    cancel()
    current_suggestion =
      string.sub(current_suggestion, 0, eot - #eot_placeholder)
    current_suggestion = util.trim(current_suggestion)
  end

  render()
end

---@return boolean
local function can_get()
  -- mode is insert or replace
  local mode = vim.api.nvim_get_mode()
  if mode.mode ~= "i" and mode.mode ~= "r" then
    return false
  end

  -- buffer exists
  local buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(buf)
  if buf_name == "" then
    return false
  end

  -- cursor at end of line
  if vim.fn.col(".") <= #vim.api.nvim_get_current_line() then
    return false
  end

  return true
end

---@param prefix string
---@param suffix string
---@return string
local function get_prompt(prefix, suffix)
  local opts = options.get()

  return opts.prompt.prefix
    .. prefix
    .. opts.prompt.suffix
    .. suffix
    .. opts.prompt.middle
end

local function get()
  if not can_get() then
    return
  end

  if not ollama.is_ready() then
    ollama.init(function()
      get()
    end)
  end

  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  local opts = options.get()
  local timer = vim.uv.new_timer()
  if
    timer:start(opts.debounce, 0, function()
      debounce_timer = nil
      async.util.scheduler(function()
        local row = vim.fn.line(".")

        local prefix = util.join(util.get_lines(0, row))
        local suffix = util.join(util.get_lines(row))

        context_line = vim.api.nvim_get_current_line()
        context_row = row

        local prompt = get_prompt(prefix, suffix)

        ollama.generate(prompt, on_data)
      end)
    end) == 0
  then
    debounce_timer = timer
  end
end

---@return boolean
local function contains_context()
  if vim.fn.line(".") ~= context_row then
    return false
  end

  local current_line = vim.api.nvim_get_current_line()

  local suggestion_lines = vim.split(current_suggestion, "\n")

  return (context_line .. suggestion_lines[1]) == current_line
    or string.find(
        context_line .. suggestion_lines[1],
        vim.pesc(current_line)
      )
      ~= nil
end

---@return boolean success true if successful
local function accept_word()
  if current_suggestion == "" then
    return false
  end

  local suggestion_lines = vim.split(current_suggestion, "\n")

  local current_line = context_line .. suggestion_lines[1]

  local insert_lines = {}

  local col = vim.fn.col(".")
  if suggestion_lines[1] == "" then
    col = 1

    context_row = context_row + 1
    table.remove(suggestion_lines, 1)
    current_line = suggestion_lines[1]

    table.insert(insert_lines, vim.api.nvim_get_current_line())
  end

  local _, word_end = string.find(current_line, "[^%s][%s.]", col + 1)
  if word_end ~= nil then
    suggestion_lines[1] = string.sub(current_line, word_end)

    current_line = string.sub(current_line, 1, word_end - 1)
  end
  if word_end == nil then
    suggestion_lines[1] = ""
  end

  context_line = current_line

  table.insert(insert_lines, current_line)

  local line = vim.fn.line(".")

  util.set_lines(line - 1, line, insert_lines)
  util.set_cursor(line + #insert_lines - 1, #current_line)

  current_suggestion = util.join(suggestion_lines, "\n")

  return true
end

---@return boolean success true if successful
local function accept_line()
  if current_suggestion == "" then
    return false
  end

  local suggestion_lines = vim.split(current_suggestion, "\n")

  local insert_lines = {}

  if suggestion_lines[1] == "" then
    context_line = ""
    context_row = context_row + 1
    table.remove(suggestion_lines, 1)

    table.insert(insert_lines, vim.api.nvim_get_current_line())
  end

  context_line = context_line .. suggestion_lines[1]
  table.insert(insert_lines, context_line)

  local line = vim.fn.line(".")

  util.set_lines(line - 1, line, insert_lines)
  util.set_cursor(line + #insert_lines - 1, #context_line)

  suggestion_lines[1] = ""
  current_suggestion = util.join(suggestion_lines, "\n")

  return true
end

---@return boolean success true if successful
local function accept_block()
  if current_suggestion == "" then
    return false
  end

  local next_lines = {}

  local blocks = vim.split(current_suggestion, "\n\n")
  if blocks[1] == "" then
    context_line = ""
    context_row = context_row + 2
    table.remove(blocks, 1)
    table.insert(next_lines, 1, vim.api.nvim_get_current_line())
    table.insert(next_lines, 2, "")
  end

  local current_line = vim.api.nvim_get_current_line()
  local col = string.find(current_line, "[^%s]") or vim.fn.col(".")
  local block = blocks[1]
  local next = 2
  while
    blocks[next] ~= nil
    and blocks[next] ~= ""
    and string.find(blocks[next], "%s", col) == 1
  do
    block = block .. "\n\n" .. blocks[next]
    next = next + 1
  end

  local block_lines = vim.split(block, "\n")
  block_lines[1] = context_line .. block_lines[1]

  for k, v in pairs(next_lines) do
    table.insert(block_lines, k, v)
  end

  local line = vim.fn.line(".")

  util.set_lines(line - 1, line, block_lines)
  util.set_cursor(line - 1 + #block_lines, #block_lines[#block_lines])

  current_suggestion = string.sub(current_suggestion, #block + #next_lines + 1)
  context_line = block_lines[#block_lines]
  context_row = line - 1 + #block_lines

  return true
end

return {
  accept_block = accept_block,
  accept_line = accept_line,
  accept_word = accept_word,
  cancel = cancel,
  contains_context = contains_context,
  get = get,
  render = render,
}
