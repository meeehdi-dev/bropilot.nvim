local async = require("plenary.async")
local util = require("bropilot.util")
local virtual_text = require("bropilot.virtual-text")
local llm = require("bropilot.llm")
local options = require("bropilot.options")

local current_suggestion = ""
local context_line_before = ""
local context_line_after = ""
local context_row = -1
local context_col = -1
---@type uv.uv_timer_t | nil
local debounce_timer = nil
local debounce = 0

local function cancel()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
  llm.cancel()
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
    context_line_before .. suggestion_lines[1] .. context_line_after,
    vim.pesc(vim.api.nvim_get_current_line())
  )

  if end_ ~= nil then
    suggestion_lines[1] = string.sub(
      context_line_before .. suggestion_lines[1] .. context_line_after,
      end_ + 1
    )
  end

  virtual_text.render(suggestion_lines, context_col)
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

  return true
end

---@param invoked boolean | nil
local function get(invoked)
  if not can_get() then
    return
  end

  if not llm.is_ready() then
    llm.init(function()
      get(invoked)
    end)
    return
  end

  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  local opts = options.get()
  local timer = vim.uv.new_timer()
  if timer == nil then
    return
  end

  if opts.auto_suggest then
    debounce = opts.debounce
  end

  if
    timer:start(debounce, 0, function()
      debounce_timer = nil
      async.util.scheduler(function()
        local row = vim.fn.line(".")
        local col = vim.fn.col(".")

        local current_line = util.get_lines(row - 1, row)[1]

        local prefix_last_line = string.sub(current_line, 0, col - 1)
        local suffix_first_line = string.sub(current_line, col)

        local prefix_lines = util.get_lines(0, row - 1)
        table.insert(prefix_lines, prefix_last_line)

        local suffix_lines = util.get_lines(row)
        if suffix_first_line ~= "" then
          table.insert(suffix_lines, 1, suffix_first_line)
        end

        local context_line = vim.api.nvim_get_current_line()
        context_line_before = string.sub(context_line, 0, col - 1)
        context_line_after = string.sub(context_line, col)
        context_row = row
        context_col = col

        llm.generate(on_data, invoked)
      end)
    end) == 0
  then
    debounce_timer = timer
  end
end

local function get_next()
  if not llm.is_ready() then
    llm.init(function()
      get_next()
    end)
    return
  end

  llm.generate_next()
end

---@param inserting boolean
---@return boolean
local function contains_context(inserting)
  if vim.fn.line(".") ~= context_row then
    return false
  end

  local current_line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".")
  current_line = string.sub(current_line, 1, col)
  if inserting then
    context_col = col
  end

  local suggestion_lines = vim.split(current_suggestion, "\n")

  return (context_line_before .. suggestion_lines[1] .. context_line_after)
      == current_line
    or string.find(
        context_line_before .. suggestion_lines[1] .. context_line_after,
        vim.pesc(current_line)
      )
      ~= nil
end

local function add_undo_breakpoint()
  local undo = vim.api.nvim_replace_termcodes("<C-g>u", true, true, true)
  vim.api.nvim_feedkeys(undo, "n", true)
end

---@return boolean success true if successful
local function accept_word()
  if current_suggestion == "" or current_suggestion == "\n" then
    return false
  end

  add_undo_breakpoint()

  local suggestion_lines = vim.split(current_suggestion, "\n")

  local insert_lines = {}

  local col = vim.fn.col(".")
  if suggestion_lines[1] == "" then
    col = 1

    context_row = context_row + 1
    table.remove(suggestion_lines, 1)
    context_line_before = ""
    context_line_after = ""

    table.insert(insert_lines, vim.api.nvim_get_current_line())
  end

  local current_line = context_line_before
    .. suggestion_lines[1]
    .. context_line_after

  local _, word_end = string.find(current_line, "[^%s][%s.]", col + 1)
  if word_end ~= nil then
    suggestion_lines[1] =
      string.sub(suggestion_lines[1], word_end - #context_line_before)
  end
  if word_end == nil then
    word_end = #context_line_before + #suggestion_lines[1] + 1
    suggestion_lines[1] = ""
  end

  context_line_before = string.sub(current_line, 0, word_end - 1)
  current_line = context_line_before .. context_line_after

  table.insert(insert_lines, current_line)

  local line = vim.fn.line(".")

  util.set_lines(line - 1, line, insert_lines)
  util.set_cursor(line + #insert_lines - 1, #context_line_before)

  context_col = #context_line_before

  current_suggestion = util.join(suggestion_lines, "\n")

  llm.accept(current_suggestion)

  return true
end

---@return boolean success true if successful
local function accept_line()
  if current_suggestion == "" or current_suggestion == "\n" then
    return false
  end

  add_undo_breakpoint()

  local suggestion_lines = vim.split(current_suggestion, "\n")

  local insert_lines = {}

  if suggestion_lines[1] == "" then
    context_line_before = ""
    context_line_after = ""
    context_row = context_row + 1
    table.remove(suggestion_lines, 1)

    table.insert(insert_lines, vim.api.nvim_get_current_line())
  end

  local context_line = context_line_before
    .. suggestion_lines[1]
    .. context_line_after
  context_line_after = ""
  table.insert(insert_lines, context_line)

  local line = vim.fn.line(".")

  util.set_lines(line - 1, line, insert_lines)
  util.set_cursor(
    line + #insert_lines - 1,
    #(context_line_before .. suggestion_lines[1])
  )

  context_col = #(context_line_before .. suggestion_lines[1])

  context_line_before = context_line_before .. suggestion_lines[1]
  suggestion_lines[1] = ""
  current_suggestion = util.join(suggestion_lines, "\n")

  llm.accept(current_suggestion)

  return true
end

---@return boolean success true if successful
local function accept_block()
  if context_line_after ~= "" then
    return accept_line()
  end

  if current_suggestion == "" or current_suggestion == "\n" then
    return llm.accept_next()
  end

  add_undo_breakpoint()

  local next_lines = {}

  local blocks = vim.split(current_suggestion, "\n\n")
  if blocks[1] == "" then
    context_line_before = ""
    context_line_after = ""
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
  block_lines[1] = context_line_before .. block_lines[1] .. context_line_after

  for k, v in pairs(next_lines) do
    table.insert(block_lines, k, v)
  end

  local line = vim.fn.line(".")

  if block_lines[#block_lines] == "" then
    table.remove(block_lines, #block_lines)
  end

  util.set_lines(line - 1, line, block_lines)
  util.set_cursor(line - 1 + #block_lines, #block_lines[#block_lines])

  current_suggestion = string.sub(current_suggestion, #block + #next_lines + 1)
  context_line_before = block_lines[#block_lines]
  context_line_after = ""
  context_row = line - 1 + #block_lines

  context_col = #block_lines[#block_lines]

  llm.accept(current_suggestion)

  return true
end

return {
  accept_block = accept_block,
  accept_line = accept_line,
  accept_word = accept_word,
  cancel = cancel,
  contains_context = contains_context,
  get = get,
  get_next = get_next,
  render = render,
}
