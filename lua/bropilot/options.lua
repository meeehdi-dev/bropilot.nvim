local presets = require("bropilot.presets")

---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: string[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number, min_p?: number }
---@alias ModelPrompt { prefix: string, suffix: string, middle: string }
---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, suggest: string }
---@alias BroOptions { auto_suggest?: boolean, excluded_filetypes?: string[], model: string, model_params?: ModelParams, prompt?: ModelPrompt, debounce: number, keymap: KeymapParams, ollama_url: string }

---@type BroOptions
local options = {
  auto_suggest = true,
  excluded_filetypes = {},
  model = "qwen2.5-coder:1.5b-base",
  preset = true,
  debounce = 500,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    suggest = "<C-Down>",
  },
  ollama_url = "http://localhost:11434/api",
}

---@param opts BroOptions
---@return BroOptions | nil
local function set(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})
  if not options.preset then
    return options
  end

  local model_name = vim.split(options.model, ":")[1]
  if presets[model_name] then
    if not options.model_params then
      options.model_params = presets[model_name].model_params
    end
    if not options.prompt then
      options.prompt = presets[model_name].prompt
    end
  end
  if not options.prompt then
    vim.notify("missing configuration for " .. model_name, vim.log.levels.ERROR)
    return nil
  end
  return options
end

---@return BroOptions
local function get()
  return options
end

return {
  get = get,
  set = set,
}
