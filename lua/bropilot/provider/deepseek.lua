local options = require("bropilot.options")
local base = require("bropilot.provider.base")

return base.create("ollama", function()
  local opts = options.get()
  return {
    provider = "deepseek",
    params = {
      model = opts.model,
      api_key = opts.api_key,
      model_params = opts.model_params,
    },
  }
end)
