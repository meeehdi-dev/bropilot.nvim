local codestral = require("bropilot.codestral")
local ollama = require("bropilot.ollama")
local options = require("bropilot.options")

local providers = {
  ollama = ollama,
  codestral = codestral
}

---@param pid number | nil
local function cancel(pid)
  local opts = options.get()
  local provider = providers[opts.provider]

  return provider.cancel(pid)
end

---@param before string
---@param after string
---@param cb function
local function generate(before, after, cb)
  local opts = options.get()
  local provider = providers[opts.provider]

  return provider.generate(before, after, cb)
end

local function is_ready()
  local opts = options.get()
  local provider = providers[opts.provider]

  return provider.is_ready()
end

---@param cb function | nil
local function init(cb)
  local opts = options.get()
  local provider = providers[opts.provider]

  return provider.init(cb)
end

return {
  generate = generate,
  cancel = cancel,
  is_ready = is_ready,
  init = init,
}
