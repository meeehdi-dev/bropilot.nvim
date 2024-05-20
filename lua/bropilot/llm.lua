local curl = require("plenary.curl")
local async = require("plenary.async")
local util = require("bropilot.util")

---@type job | nil
local suggestion_job = nil
---@type string
local suggestion = ""
---@type string
local context_line = ""
local suggestion_progress_handle = nil
---@type boolean
local ready = false
---@type boolean
local initializing = false
---@type uv_timer_t | nil
local debounce_timer = nil

---@alias Options {model: string, prompt: { prefix: string, suffix: string, middle: string }, debounce: number, auto_pull: boolean}

local M = {}

---@param prefix string
---@param suffix string
---@return string
local get_prompt = function(prefix, suffix)
  return M.opts.prompt.prefix
    .. prefix
    .. M.opts.prompt.suffix
    .. suffix
    .. M.opts.prompt.middle
end

---@param data string
local function on_data(data)
  if data == nil then
    return
  end

  local body = vim.json.decode(data)
  if body.done then
    util.finish_progress(suggestion_progress_handle)
  end

  suggestion = suggestion .. (body.response or "")

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

local function do_suggest()
  local row, col = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]

  if col < #current_line then
    -- TODO: trim but only trailing whitespace (not vim.trim()...)
    return -- cancel because cursor is before end of line
  end

  local prefix, suffix = util.get_context()

  context_line = current_line
  suggestion_progress_handle = util.get_progress_handle("Suggesting...")
  suggestion_job = curl.post("http://localhost:11434/api/generate", {
    body = vim.json.encode({
      model = M.opts.model,
      prompt = get_prompt(prefix, suffix),
    }),
    callback = function()
      util.finish_progress(suggestion_progress_handle)
    end,
    stream = function(err, data)
      async.util.scheduler(function()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
        on_data(data)
      end)
    end,
  })
end

function M.cancel()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end
  if suggestion_job then
    pcall(suggestion_job.shutdown, suggestion_job)
    suggestion_job = nil
  end
  util.finish_progress(suggestion_progress_handle)
end

function M.clear()
  suggestion = ""
  util.clear_virtual_text()
end

---@param model string
---@param cb function
local function find_model(model, cb)
  local find_progress_handle =
    util.get_progress_handle("Checking model " .. model)
  local check_job = curl.get("http://localhost:11434/api/tags", {
    callback = function(data)
      async.util.scheduler(function()
        util.finish_progress(find_progress_handle)
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
        initializing = false
        cb()
      end)
    end,
  })
  preload_job:start()
end

---@param model string
---@param cb function
local function pull_model(model, cb)
  local pull_progress_handle =
    util.get_progress_handle("Pulling model " .. model)
  local pull_job = curl.post("http://localhost:11434/api/pull", {
    body = vim.json.encode({ name = model }),
    callback = function()
      async.util.scheduler(function()
        util.finish_progress(pull_progress_handle)
      end)
    end,
    stream = function(err, data)
      async.util.scheduler(function()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
        local body = vim.json.decode(data)
        if pull_progress_handle ~= nil then
          if body.status == "success" then
            util.finish_progress(pull_progress_handle)
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
end

---@param init_options Options
---@param cb function
function M.init(init_options, cb)
  if ready or initializing then
    return
  end
  initializing = true
  M.opts = init_options
  find_model(M.opts.model, function(found)
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
  if suggestion == "" then
    util.clear_virtual_text()
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

function M.suggest()
  if not ready then
    M.init(M.opts, M.suggest)
    return
  end

  local timer = vim.uv.new_timer()
  if
    timer:start(M.opts.debounce, 0, function()
      async.util.scheduler(function()
        do_suggest()
      end)
    end) == 0
  then
    debounce_timer = timer
  end
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
