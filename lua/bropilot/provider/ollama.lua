local options = require("bropilot.options")
local base = require("bropilot.provider.base")

return base.create("ollama", function()
  local opts = options.get()
  return {
    provider = "ollama",
    params = {
      url = opts.ollama_url,
      model = opts.model,
      model_params = opts.model_params,
    },
  }
end)
