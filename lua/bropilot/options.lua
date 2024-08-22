---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: string[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number, min_p?: number }
---@alias ModelPrompt { prefix: string, suffix: string, middle: string }
---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, resuggest: string }
---@alias Options { model: string, model_params?: ModelParams, prompt: ModelPrompt, debounce: number, keymap: KeymapParams, ollama_url: string }

---@type Options
local options = {
  model = "starcoder2:3b",
  model_params = {
    num_ctx = 4096,
    num_predict = -2,
    temperature = 0.75,
    stop = { "<file_sep>" },
  },
  prompt = {
    prefix = "<fim_prefix>",
    suffix = "<fim_suffix>",
    middle = "<fim_middle>",
  },
  debounce = 1000,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    resuggest = "<C-Down>",
  },
  ollama_url = "http://localhost:11434/api",
}

---@param opts Options
local function set(opts)
  options = vim.tbl_deep_extend("force", options, opts or {})
end

---@return Options
local function get()
  return options
end

return {
  get = get,
  set = set,
}
