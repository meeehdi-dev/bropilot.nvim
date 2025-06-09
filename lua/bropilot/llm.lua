local provider = require("bropilot.provider")

---@param pid number | nil
local function cancel(pid)
  return provider.get().cancel(pid)
end

---@param cb fun()
local function generate(cb)
  return provider.get().generate(cb)
end

local function generate_next()
  return provider.get().generate_next()
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

---@return boolean
local function accept_next()
  if provider.get().accept_next then
    return provider.get().accept_next()
  end
  return false
end

return {
  generate = generate,
  generate_next = generate_next,
  cancel = cancel,
  is_ready = is_ready,
  init = init,
  accept = accept,
  accept_next = accept_next,
}
