local options = require("bropilot.options")

---@alias Provider { is_ready: (fun(): boolean), init: (fun(cb: fun() | nil)), cancel: (fun(pid: number | nil)), generate: (fun(before: string, after: string, cb: fun())), accept?: (fun(suggestion_left: string)), accept_next?: (fun(): boolean), generate_next?: (fun()) }

---@return Provider
local function get()
  local opts = options.get()
  return require("bropilot." .. opts.provider)
end

return { get = get }
