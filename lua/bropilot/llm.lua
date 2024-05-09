local curl = require("plenary.curl")
local Job = require("plenary.job")
local async = require("plenary.async")
local util = require("bropilot.util")

local debounce_job_pid = -1
local suggestion_job_pid = -1
local suggestion = ""
local context_line = ""
local suggestion_progress_handle = nil
local ready = false

---@alias Options {model: string, debounce: number, auto_pull: boolean}

local M = {}

---@type table<string, {prefix: string, suffix: string, middle: string}>
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

---@param model string
---@param prefix string
---@param suffix string
---@return string
local get_prompt = function(model, prefix, suffix)
  local model_name = vim.split(model, ":")[1]
  local prompt_data = prompt_map[model_name]
  if prompt_data == nil then
    vim.notify(
      "No prompt found for " .. model,
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

---@param model string
---@param cb function
local function check_model(model, cb)
  local check_progress_handle =
    util.get_progress_handle("Checking model " .. model)
  local check_job = curl.get("http://localhost:11434/api/tags", {
    callback = function(data)
      async.util.scheduler(function()
        if check_progress_handle ~= nil then
          check_progress_handle:finish()
          check_progress_handle = nil
        end
        local body = vim.json.decode(data.body)
        for _, v in ipairs(body.models) do
          if v.name == model then
            cb(true)
            return
          end
        end
        cb(false)
      end)
    end,
  })
  check_job:start()
end

---@param model string
---@param cb function
local function pull_model(model, cb)
  local pull_progress_handle =
    util.get_progress_handle("Pulling model " .. model)
  local pull_job_pid = -1
  local pull_job = curl.post("http://localhost:11434/api/pull", {
    body = vim.json.encode({ name = model }),
    callback = function()
      async.util.scheduler(function()
        pull_job_pid = -1
        if pull_progress_handle ~= nil then
          pull_progress_handle:cancel()
          pull_progress_handle = nil
        end
      end)
    end,
    stream = function(err, data, p_job)
      async.util.scheduler(function()
        if pull_job_pid ~= p_job.pid then
          return
        end
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
        local body = vim.json.decode(data)
        if pull_progress_handle ~= nil then
          if body.status == "success" then
            pull_progress_handle:finish()
            pull_progress_handle = nil
            cb()
          else
            local report = {}
            if body.status then
              report.message = body.status
            end
            if body.completed ~= nil and body.total ~= nil then
              report.percentage = body.completed / body.total * 100
            end
            pull_progress_handle:report(report)
          end
        end
      end)
    end,
  })
  pull_job:start()
  pull_job_pid = pull_job.pid
end

---@param model string
---@param cb function | nil
local function preload_model(model, cb)
  local preload_progress_handle =
    util.get_progress_handle("Preloading " .. model)
  local preload_job = curl.post("http://localhost:11434/api/generate", {
    body = vim.json.encode({
      model = model,
      keep_alive = "10m",
    }),
    callback = function()
      async.util.scheduler(function()
        if preload_progress_handle ~= nil then
          preload_progress_handle:finish()
          preload_progress_handle = nil
        end
        ready = true
        if cb ~= nil then
          cb()
        end
      end)
    end,
  })
  preload_job:start()
end

---@param init_options Options
---@param cb function | nil
function M.init(init_options, cb)
  M.opts = init_options
  check_model(M.opts.model, function(found)
    if found then
      preload_model(M.opts.model, cb)
    else
      if M.opts.auto_pull then
        pull_model(M.opts.model, function()
          preload_model(M.opts.model, cb)
        end)
      else
        vim.notify(M.opts.model .. " not found", vim.log.levels.ERROR)
      end
    end
  end)
end

function M.render_suggestion()
  M.clear()

  if suggestion == "" then
    return
  end

  -- keep showing all suggestions but accept only block by block
  local block = vim.split(suggestion, "\n\n")[1] -- only take first block when rendering
  local suggestion_lines = vim.split(block, "\n")
  -- FIXME: seems to not work anymore? weirdge
  -- local suggestion_lines = vim.split(suggestion, "\n")

  if suggestion_lines[1] ~= "" then
    local row, col = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]
    local diff = #current_line - #context_line
    if diff > 0 then
      suggestion_lines[1] = string.sub(current_line, col + 1)
        .. string.sub(suggestion_lines[1], diff + 1)
    end
  end

  util.render_virtual_text(suggestion_lines)
end

---@param data string
local function on_data(data)
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
end

---@param model string
---@param current_line string
function M.suggest(model, current_line)
  local _, col = util.get_cursor()
  if col < #current_line then
    -- TODO: trim but only trailing whitespace (not vim.trim()...)
    return -- cancel because cursor is before end of line
  end

  if not ready then
    M.init(M.opts, function()
      M.suggest(model, current_line)
    end)
    return
  end
  local prefix, suffix = util.get_context()

  local debounce_job = Job:new({
    command = "sleep",
    args = { tostring(M.opts.debounce / 1000) },
    on_exit = function(d_job)
      async.util.scheduler(function()
        if debounce_job_pid ~= d_job.pid then
          return
        end
        debounce_job_pid = -1

        context_line = current_line
        if suggestion_progress_handle == nil then
          suggestion_progress_handle = util.get_progress_handle("Suggesting...")
        end
        local suggestion_job =
          curl.post("http://localhost:11434/api/generate", {
            body = vim.json.encode({
              model = model,
              prompt = get_prompt(model, prefix, suffix),
            }),
            callback = function()
              async.util.scheduler(function()
                suggestion_job_pid = -1
                if suggestion_progress_handle ~= nil then
                  suggestion_progress_handle:cancel()
                  suggestion_progress_handle = nil
                end
              end)
            end,
            stream = function(err, data, s_job)
              async.util.scheduler(function()
                if suggestion_job_pid ~= s_job.pid then
                  return
                end
                if err then
                  vim.notify(err, vim.log.levels.ERROR)
                end
                on_data(data)
              end)
            end,
          })
        suggestion_job_pid = suggestion_job.pid
      end)
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
  local row = util.get_cursor()
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
  local last_line = suggestion_lines[#suggestion_lines]
  local col = #last_line
  if last_line == "" then
    col = 0
  end
  vim.api.nvim_win_set_cursor(0, { start + #suggestion_lines, col })

  -- FIXME: doesn't work atm
  suggestion = string.sub(suggestion, sug_start + len + 1) -- remove first block
  context_line = ""
end

return M
