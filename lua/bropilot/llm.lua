local curl = require("plenary.curl")
local Job = require("plenary.job")
local async = require("plenary.async")
local util = require("bropilot.util")

local debounce_job_pid = -1
local suggestion_job_pid = -1
local ready_job_pid = -1
local suggestion = ""
local context_line = ""
local suggestion_progress_handle = nil
local ready = false

---@alias Options {model: Model, variant: string, debounce: number}
---@alias Model "codellama" | "codegemma" | "starcoder2"

---@type Options
local opts = {}

local M = {}

---@type table<Model, {prefix: string, suffix: string, middle: string}>
local prompt_map = {
  codellama = { prefix = "<PRE> ", suffix = " <SUF>", middle = " <MID>" },
  codegemma = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  starcoder2 = {
    prefix = "<fim_prefix>",
    suffix = "<fim_suffix>",
    middle = "<fim_middle>",
  },
}

---@param model Model
---@param prefix string
---@param suffix string
---@return string
local get_prompt = function(model, prefix, suffix)
  local prompt_data = prompt_map[model]
  if prompt_data == nil then
    vim.notify(
      "No prompt found for model " .. model .. " (" .. model .. ")",
      vim.log.levels.ERROR
    )
    return ""
  end
  return prompt_data.prefix
    .. prefix
    .. prompt_data.suffix
    .. suffix
    .. prompt_data.middle
end

function M.cancel()
  if debounce_job_pid ~= -1 then
    local kill = debounce_job_pid
    debounce_job_pid = -1
    pcall(function()
      io.popen("kill " .. kill)
    end)
  end
  if suggestion_job_pid ~= -1 then
    local kill = suggestion_job_pid
    suggestion_job_pid = -1
    pcall(function()
      io.popen("kill " .. kill)
    end)
  end
  if ready_job_pid ~= -1 then
    local kill = ready_job_pid
    ready_job_pid = -1
    pcall(function()
      io.popen("kill " .. kill)
    end)
  end
  if suggestion_progress_handle ~= nil then
    suggestion_progress_handle:cancel()
    suggestion_progress_handle = nil
  end
end

---@param force boolean | nil
function M.clear(force)
  if force then
    suggestion = ""
  end
  util.clear_virtual_text()
end

---@param model Model
---@param variant string
local function preload_model(model, variant)
  local model_name = util.join({ model, variant }, ":")
  local preload_progress_handle =
    util.get_progress_handle("Preloading " .. model_name)
  local preload_job = curl.post("http://localhost:11434/api/generate", {
    body = vim.json.encode({
      model = model_name,
      keep_alive = "10m",
    }),
    callback = function()
      if preload_progress_handle ~= nil then
        preload_progress_handle:finish()
        preload_progress_handle = nil
      end
      ready = true
    end,
  })
  preload_job:start()
end

---@param init_options Options
function M.init(init_options)
  opts = init_options
  preload_model(opts.model, opts.variant)
end

function M.render_suggestion()
  M.clear()

  if suggestion == "" then
    return
  end

  -- keep showing all suggestions but accept only block by block
  -- local block = vim.split(suggestion, "\n\n")[1] -- only take first block when rendering
  -- local suggestion_lines = vim.split(block, "\n")
  local suggestion_lines = vim.split(suggestion, "\n")

  if suggestion_lines[1] ~= "" then
    local row, col = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]
    local diff = #current_line - #context_line
    if diff > 0 then
      suggestion_lines[1] = string.sub(current_line, col + 1) .. string.sub(suggestion_lines[1], diff + 1)
    end
  end

  util.render_virtual_text(suggestion_lines)
end

---@param data string
local function on_data(data)
  async.util.scheduler(function()
    local body = vim.json.decode(data)
    if body.done then
      suggestion_job_pid = -1
      if suggestion_progress_handle ~= nil then
        suggestion_progress_handle:finish()
        suggestion_progress_handle = nil
      end
      return
    end

    suggestion = suggestion .. (body.response or "")

    M.clear()

    local eot_placeholder = "<EOT>"
    local _, eot = string.find(suggestion, eot_placeholder)
    if eot then
      M.cancel()
      suggestion = string.sub(suggestion, 0, eot - #eot_placeholder)
    end
    -- TODO: use in option (default should be true, bc suggestions can be long af)
    -- local block_placeholder = "\n\n"
    -- local _, block = string.find(suggestion, block_placeholder)
    -- if block then
    --   M.cancel()
    --   suggestion = string.sub(suggestion, 0, block - #block_placeholder)
    -- end

    M.render_suggestion()
  end)
end

---@param model Model
---@param variant string
---@param current_line string
function M.suggest(model, variant, current_line)
  local _, col = util.get_cursor()
  if col < #current_line then
    -- TODO: trim but only trailing whitespace (not vim.trim()...)
    return -- cancel because cursor is before end of line
  end

  if not ready then
    M.cancel()
    local ready_job = Job:new({
      command = "sleep",
      args = { 0.1 },
      on_exit = function(r_job)
        if ready_job_pid ~= r_job.pid then
          return
        end
        ready_job_pid = -1
        M.suggest(model, variant, current_line)
      end,
    })
    ready_job:start()
    return
  end
  local prefix, suffix = util.get_context()

  local debounce_job = Job:new({
    command = "sleep",
    args = { tostring(opts.debounce / 1000) },
    on_exit = function(d_job)
      if debounce_job_pid ~= d_job.pid then
        return
      end
      debounce_job_pid = -1

      context_line = current_line
      if suggestion_progress_handle == nil then
        suggestion_progress_handle = util.get_progress_handle("Suggesting...")
      end
      local suggestion_job = curl.post("http://localhost:11434/api/generate", {
        body = vim.json.encode({
          model = util.join({ model, variant }, ":"),
          prompt = get_prompt(model, prefix, suffix),
        }),
        callback = function()
          suggestion_job_pid = -1
          if suggestion_progress_handle ~= nil then
            suggestion_progress_handle:cancel()
            suggestion_progress_handle = nil
          end
        end,
        stream = function(err, data, s_job)
          if suggestion_job_pid ~= s_job.pid then
            return
          end
          if err then
            vim.notify(err, vim.log.levels.ERROR)
          end
          on_data(data)
        end,
      })
      suggestion_job_pid = suggestion_job.pid
    end,
  })
  debounce_job:start()
  debounce_job_pid = debounce_job.pid
end

---@return string
function M.get_suggestion()
  return suggestion
end

---@return string
function M.get_context_line()
  return context_line
end

function M.accept_word()
  if #suggestion == 0 then
    return
  end

  local block = vim.split(suggestion, "\n\n")[1]

  local suggestion_lines = vim.split(block, "\n")
  local row, col = util.get_cursor()
  local start = row - 1
  if context_line == "" and suggestion_lines[1] == "" then
    start = start + 1
    table.remove(suggestion_lines, 1)
  end
  suggestion_lines[1] = context_line .. suggestion_lines[1]

  vim.notify("NOT YET IMPLEMENTED", vim.log.levels.WARN)
end

function M.accept_line()
  if #suggestion == 0 then
    return
  end

  local block = vim.split(suggestion, "\n\n")[1]

  local suggestion_lines = vim.split(block, "\n")
  local suggestion_line = suggestion_lines[1]
  local row = util.get_cursor()
  local start = row - 1
  local sug_start = 0
  if context_line == "" and suggestion_line == "" then
    start = start + 1
    table.remove(suggestion_lines, 1)
    suggestion_line = suggestion_lines[1]
    sug_start = 1
  end
  local len = #suggestion_line
  suggestion_line = context_line .. suggestion_line
  local col = #suggestion_line
  vim.api.nvim_buf_set_lines(0, start, row, true, { suggestion_line })
  vim.api.nvim_win_set_cursor(0, { start + 1, col })

  suggestion = string.sub(suggestion, sug_start + len + 1)
  context_line = ""
end

function M.accept_block()
  if suggestion == "" then
    return
  end

  local block = vim.split(suggestion, "\n\n")[1]

  local row = util.get_cursor()
  local suggestion_lines = vim.split(block, "\n")
  local start = row - 1
  local sug_start = 0
  if context_line == "" and suggestion_lines[1] == "" then
    start = start + 1
    table.remove(suggestion_lines, 1)
    sug_start = 1
  end
  local len = #block
  suggestion_lines[1] = context_line .. suggestion_lines[1]
  vim.api.nvim_buf_set_lines(0, start, row, true, suggestion_lines)
  local col = #suggestion_lines[#suggestion_lines]
  vim.api.nvim_win_set_cursor(0, { start + #suggestion_lines, col })

  -- FIXME: doesn't work atm
  suggestion = string.sub(suggestion, sug_start + len + 2) -- remove first block
  context_line = ""
end

return M
