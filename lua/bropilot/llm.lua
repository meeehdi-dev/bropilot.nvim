local curl = require("plenary.curl")
local async = require("plenary.async")
local util = require("bropilot.util")

---@type job | nil
local suggestion_job = nil
---@type string
local suggestion = ""
---@type string
local context_line = ""
local context_row = -1
local suggestion_progress_handle = nil
---@type boolean
local ready = false
---@type boolean
local initializing = false
---@type uv_timer_t | nil
local debounce_timer = nil

---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: number[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number }
---@alias ModelPrompt { prefix: string, suffix: string, middle: string }
---@alias Options { model: string, model_params?: ModelParams, prompt: ModelPrompt, max_blocks: number, debounce: number, auto_pull: boolean }

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
local function on_suggestion_data(data)
  if data == nil or type(data) ~= "string" then
    return
  end

  local success, body = pcall(vim.json.decode, data)
  if not success then
    util.finish_progress(suggestion_progress_handle)
    return
  end
  if body.done then
    util.finish_progress(suggestion_progress_handle)
    return
  end

  suggestion = suggestion .. (body.response or "")

  local eot_placeholder = "<EOT>"
  local _, eot = string.find(suggestion, eot_placeholder)
  if eot then
    M.cancel()
    suggestion = string.sub(suggestion, 0, eot - #eot_placeholder)
  end
  if string.find(suggestion, "\n\n") ~= nil and M.opts.max_blocks ~= -1 then
    local blocks = vim.split(suggestion, "\n\n")
    if #blocks > M.opts.max_blocks then
      while #blocks > M.opts.max_blocks do
        table.remove(blocks, #blocks)
      end
      suggestion = util.join(blocks, "\n\n")
      M.cancel()
    end
  end

  M.render_suggestion()
end

local function do_suggest()
  local row = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]

  local cursor_line = util.get_cursor()

  local prefix = util.join(util.get_lines(0, cursor_line))
  local suffix = util.join(util.get_lines(cursor_line))

  context_line = current_line
  context_row = row
  suggestion_progress_handle = util.get_progress_handle("Suggesting...")
  suggestion_job = curl.post("http://localhost:11434/api/generate", {
    body = vim.json.encode({
      model = M.opts.model,
      options = M.opts.model_params,
      prompt = get_prompt(prefix, suffix),
    }),
    callback = function(data)
      util.finish_progress(suggestion_progress_handle)
      local success, body = pcall(vim.json.decode, data.body)
      if success and body.error then
        vim.notify(body.error, vim.log.levels.ERROR)
      end
      -- else this means we force-cancelled suggestion
    end,
    on_error = function(err)
      if err.code ~= nil then
        vim.notify(err.message)
      end
    end,
    stream = function(err, data)
      async.util.scheduler(function()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
        on_suggestion_data(data)
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
    suggestion_job:shutdown()
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
        else
          vim.notify(
            "Preloaded model " .. model .. " successfully!",
            vim.log.levels.INFO
          )
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
          if body.error then
            vim.notify(body.error, vim.log.levels.ERROR)
            util.finish_progress(pull_progress_handle)
          elseif body.status == "success" then
            util.finish_progress(pull_progress_handle)
            cb()
          else
            local report = { message = "", percentage = 100 }
            if body.status then
              report.message = body.status
            end
            if body.completed ~= nil and body.total ~= nil then
              report.percentage = body.completed / body.total * 100
            end
            pull_progress_handle:report(report)
          end
        else
          if body.error then
            vim.notify(body.error, vim.log.levels.ERROR)
          elseif body.status == "success" then
            vim.notify(
              "Pulled model " .. model .. " successfully!",
              vim.log.levels.INFO
            )
            cb()
          else
            local report = { message = "", percentage = 100 }
            if body.status then
              report.message = body.status
            end
            if body.completed ~= nil and body.total ~= nil then
              report.percentage = body.completed / body.total * 100
            end
            vim.notify(
              "Pulling model: "
                .. report.message
                .. " ("
                .. report.percentage
                .. "%)",
              vim.log.levels.INFO
            )
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

  local suggestion_lines = vim.split(suggestion, "\n")

  local row, col = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]

  if col < #current_line then
    return
  end

  local _, end_ = string.find(
    vim.pesc(context_line .. suggestion_lines[1]),
    vim.pesc(current_line)
  )
  if end_ ~= nil then
    suggestion_lines[1] =
      string.sub(context_line .. suggestion_lines[1], end_ + 1)
  end

  util.render_virtual_text(suggestion_lines)
end

function M.suggest()
  if not ready then
    M.init(M.opts, function()
      local mode = vim.api.nvim_get_mode()

      if mode == "i" or mode == "r" then
        M.suggest()
      end
    end)
    return
  end

  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  local timer = vim.uv.new_timer()
  if
    timer:start(M.opts.debounce, 0, function()
      debounce_timer = nil
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

---@return number
function M.get_context_row()
  return context_row
end

function M.accept_word()
  if #suggestion == 0 then
    return
  end

  local suggestion_lines = vim.split(suggestion, "\n")

  local row = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]
  local _, end_ = string.find(
    vim.pesc(context_line .. suggestion_lines[1]),
    vim.pesc(current_line)
  )
  if end_ ~= nil then
    suggestion_lines[1] =
      string.sub(context_line .. suggestion_lines[1], end_ + 1)
  end

  local _, word_end = string.find(suggestion_lines[1], "[^%s]%s")
  if word_end ~= nil then
    local suggestion_word = string.sub(suggestion_lines[1], 1, word_end - 1)

    util.set_lines(row - 1, row, { current_line .. suggestion_word })
    util.set_cursor(row, #(current_line .. suggestion_word))
  else
    local start_of_next_line = ""
    local next_line = suggestion_lines[2]
    if next_line ~= nil then
      local _, next_char_end = string.find(next_line, "[^%s]")
      if next_char_end ~= nil then
        start_of_next_line = string.sub(next_line, 1, next_char_end - 1)
        suggestion_lines[2] =
          string.sub(suggestion_lines[2], #start_of_next_line + 1)
      end
    end

    util.set_lines(
      row - 1,
      row,
      { current_line .. suggestion_lines[1], start_of_next_line }
    )
    util.set_cursor(row + 1, #start_of_next_line)

    table.remove(suggestion_lines, 1)
    suggestion = util.join(suggestion_lines, "\n")

    context_line = start_of_next_line
    context_row = row + 1
  end
end

function M.accept_line()
  if #suggestion == 0 then
    return
  end

  local suggestion_lines = vim.split(suggestion, "\n")

  local row = util.get_cursor()
  local current_line = util.get_lines(row - 1, row)[1]
  local _, end_ = string.find(
    vim.pesc(context_line .. suggestion_lines[1]),
    vim.pesc(current_line)
  )
  if end_ ~= nil then
    suggestion_lines[1] =
      string.sub(context_line .. suggestion_lines[1], end_ + 1)
  end

  local start_of_next_line = suggestion_lines[1]
  local next_line = suggestion_lines[2]
  local next_lines = { current_line .. suggestion_lines[1] }
  if next_line ~= nil then
    local _, next_char_end = string.find(next_line, "[^%s]")
    if next_char_end ~= nil then
      start_of_next_line = string.sub(next_line, 1, next_char_end - 1)
      suggestion_lines[2] =
        string.sub(suggestion_lines[2], #start_of_next_line + 1)
      table.insert(next_lines, start_of_next_line)
    end
  end

  util.set_lines(row - 1, row, next_lines)
  util.set_cursor(row + #next_lines - 1, #next_lines[1])

  table.remove(suggestion_lines, 1)
  suggestion = util.join(suggestion_lines, "\n")

  context_line = start_of_next_line
  context_row = row + #next_lines - 1
end

function M.accept_block()
  if suggestion == "" then
    return
  end

  local blocks = vim.split(suggestion, "\n\n")
  local block = blocks[1]

  local row = util.get_cursor()
  local suggestion_lines = vim.split(block, "\n")
  suggestion_lines[1] = context_line .. suggestion_lines[1]

  if blocks[2] ~= nil then
    table.insert(suggestion_lines, "")
    table.insert(suggestion_lines, "")
  end

  util.set_lines(row - 1, row, suggestion_lines)
  util.set_cursor(
    row - 1 + #suggestion_lines,
    #suggestion_lines[#suggestion_lines]
  )

  suggestion = string.sub(suggestion, #block + 2 + 1)
  context_line = suggestion_lines[#suggestion_lines]
  context_row = row - 1 + #suggestion_lines
end

return M
