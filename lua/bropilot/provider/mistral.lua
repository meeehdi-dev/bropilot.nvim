local options = require("bropilot.options")
local base = require("bropilot.provider.base")

return base.create("mistral", function()
  local opts = options.get()
  return {
    provider = "mistral",
    params = {
      api_key = opts.api_key,
    },
  }
end)
