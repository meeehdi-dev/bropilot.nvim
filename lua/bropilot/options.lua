---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: string[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number, min_p?: number }
---@alias ModelPrompt { prefix: string, suffix: string, middle: string }
---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, suggest: string }
---@alias Options { auto_suggest?: boolean, model: string, model_params?: ModelParams, prompt: ModelPrompt, debounce: number, keymap: KeymapParams, ollama_url: string }

---@type Options
local options = {
  auto_suggest = false,
  model = "deepseek-coder-v2:16b-lite-base-q4_0",
  model_params = {
    num_ctx = 16384,
    num_predict = -2,
    temperature = 0.2,
    top_p = 0.95,
  },
  prompt = {
    prefix = "<｜fim▁begin｜>",
    suffix = "<｜fim▁hole｜>",
    middle = "<｜fim▁end｜>",
  },
  debounce = 100,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    suggest = "<C-Down>",
  },
  ollama_url = "http://localhost:11434/api",
}

---@param opts Options
---@return Options
local function set(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})
  return options
end

---@return Options
local function get()
  return options
end

return {
  get = get,
  set = set,
}
