local async = require("plenary.async")
local curl = require("plenary.curl")
local util = require("bropilot.util")
local options = require("bropilot.options")
local llm = require("bropilot.llm")

local current_suggestion_pid = nil
local suggestion_handles = {}

local function is_ready()
  return true
end

local function init(cb)
  cb()
end

---@param pid number | nil
local function cancel(pid)
  if pid == nil then
    pid = current_suggestion_pid
  end

  if pid and suggestion_handles[pid] then
    local job = suggestion_handles[pid].job
    local progress = suggestion_handles[pid].progress

    job:shutdown()
    util.finish_progress(progress)

    current_suggestion_pid = nil
  end
end

---@param before string
---@param after string
---@param cb function
local function generate(before, after, cb)
  local opts = options.get()

  local truncated = llm.truncate(before, after, 32768) -- codestral context length

  local suggestion_progress_handle = util.get_progress_handle("Suggesting...")
  local suggestion_job_pid = nil
  local suggestion_job =
    curl.post("https://codestral.mistral.ai/v1/fim/completions", {
      headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json",
        ["Authorization"] = "Bearer " .. opts.api_key,
      },
      body = vim.json.encode({
        model = "codestral-latest",
        prompt = truncated.prefix,
        suffix = truncated.suffix,
        stop = "\n\n",
        max_tokens = "64",
        temperature = "0",
      }),
      on_error = function(err)
        if current_suggestion_pid ~= suggestion_job_pid then
          cancel(suggestion_job_pid)
          return
        end

        if err.exit == nil then
          -- avoid errors when cancelling a suggestion
          return
        end

        async.util.scheduler(function()
          vim.notify(err.message, vim.log.levels.ERROR)
        end)
      end,
      stream = function(err, data)
        if current_suggestion_pid ~= suggestion_job_pid then
          cancel(suggestion_job_pid)
          return
        end

        async.util.scheduler(function()
          if err then
            vim.notify(err, vim.log.levels.ERROR)
          end

          if data == nil or type(data) ~= "string" then
            return
          end

          local success, body = pcall(vim.json.decode, data)
          util.finish_progress(suggestion_progress_handle)
          current_suggestion_pid = nil
          cb(true)

          if not success then
            return
          end

          cb(false, body.choices[1].message.content)
        end)
      end,
    })
  suggestion_job_pid = suggestion_job.pid
  suggestion_handles[suggestion_job_pid] = {
    job = suggestion_job,
    progress = suggestion_progress_handle,
  }
  current_suggestion_pid = suggestion_job_pid
end

return {
  cancel = cancel,
  generate = generate,
  is_ready = is_ready,
  init = init,
}
