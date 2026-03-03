local provider = require("bropilot.provider")

---@param pid number | nil
local function cancel(pid)
  return provider.get().cancel(pid)
end

---@param cb fun()
---@param invoked boolean | nil
local function generate(cb, invoked)
  return provider.get().generate(cb, invoked)
end

local function is_ready()
  return provider.get().is_ready()
end

---@param cb fun() | nil
local function init(cb)
  return provider.get().init(cb)
end

---@param suggestion_left string
local function accept(suggestion_left)
  if provider.get().accept then
    provider.get().accept(suggestion_left)
  end
end

return {
  generate = generate,
  cancel = cancel,
  is_ready = is_ready,
  init = init,
  accept = accept,
}
