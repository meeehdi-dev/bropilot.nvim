local async = require("plenary.async")
local util = require("bropilot.util")
local virtual_text = require("bropilot.virtual-text")
local ollama = require("bropilot.ollama")
local options = require("bropilot.options")

local current_suggestion = ""
local context_line_before = ""
local context_line_after = ""
local context_row = -1
local context_col = -1
---@type uv.uv_timer_t | nil
local debounce_timer = nil
local debounce = 0 -- used to gradually increase timeout and avoid issues with curl

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
  if debounce > 0 then
    debounce = 0 -- reset debounce timer
  end

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

  -- cursor at end of line
  -- if vim.fn.col(".") <= #vim.api.nvim_get_current_line() then
  --   return false
  -- end

  return true
end

---@param prefix string
---@param suffix string
---@return string
local function get_prompt(prefix, suffix)
  local opts = options.get()
  local num_ctx = opts.model_params.num_ctx

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
  if timer == nil then
    return
  end

  if debounce <= 0 then
    debounce = opts.debounce
  end

  if
    timer:start(debounce, 0, function()
      debounce_timer = nil
      async.util.scheduler(function()
        if debounce > 0 then
          debounce = debounce * 1.5
        end

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

        local prefix = util.join(prefix_lines)
        local suffix = util.join(suffix_lines)

        local context_line = vim.api.nvim_get_current_line()
        context_line_before = string.sub(context_line, 0, col - 1)
        context_line_after = string.sub(context_line, col)
        context_row = row
        context_col = col

        local prompt = get_prompt(prefix, suffix)

        ollama.generate(prompt, on_data)
      end)
    end) == 0
  then
    debounce_timer = timer
  end
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
    suggestion_lines[1] = ""
    word_end = #current_line + 1
  end

  context_line_before = string.sub(current_line, 0, word_end - 1)
  current_line = context_line_before .. context_line_after

  table.insert(insert_lines, current_line)

  local line = vim.fn.line(".")

  util.set_lines(line - 1, line, insert_lines)
  util.set_cursor(line + #insert_lines - 1, #context_line_before)

  current_suggestion = util.join(suggestion_lines, "\n")

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

  context_line_before = context_line_before .. suggestion_lines[1]
  suggestion_lines[1] = ""
  current_suggestion = util.join(suggestion_lines, "\n")

  return true
end

---@return boolean success true if successful
local function accept_block()
  if context_line_after ~= "" then
    return accept_line()
  end

  if current_suggestion == "" or current_suggestion == "\n" then
    return false
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
