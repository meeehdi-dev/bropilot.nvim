local options = require("bropilot.options")
local base = require("bropilot.provider.base")

return base.create("gemini", function()
  local opts = options.get()
  return {
    provider = "gemini",
    params = {
      api_key = opts.api_key,
    },
  }
end)
