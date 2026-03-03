local options = require("bropilot.options")
local base = require("bropilot.provider.base")

return base.create("codestral", function()
  local opts = options.get()
  return {
    provider = "codestral",
    params = {
      api_key = opts.api_key,
    },
  }
end)
