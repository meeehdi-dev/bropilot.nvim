local options = require("bropilot.options")

---@alias Provider { is_ready: (fun(): boolean), init: (fun(cb: fun() | nil)), cancel: (fun(pid: number | nil)), generate: (fun(cb: fun(), invoked: boolean | nil)), accept?: (fun(suggestion_left: string)) }

---@return Provider
local function get()
  local opts = options.get()
  return require("bropilot.provider." .. opts.provider)
end

return { get = get }
