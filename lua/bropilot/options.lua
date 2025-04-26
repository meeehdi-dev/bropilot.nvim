---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: string[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number, min_p?: number }
---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, suggest: string, suggest_next: string }
---@alias BroOptions { provider: "ollama" | "codestral", api_key?: string, auto_suggest?: boolean, excluded_filetypes?: string[], model?: string, model_params?: ModelParams, debounce: number, keymap: KeymapParams, ollama_url: string }

---@type BroOptions
local default_opts = {
  provider = "ollama",
  auto_suggest = true,
  excluded_filetypes = {},
  model = "qwen2.5-coder:0.5b",
  model_params = {
    num_ctx = 32768,
    num_predict = -1,
    temperature = 0,
    top_p = 0.95,
    max_tokens = 64,
    stop = { "<|fim_pad|>", "<|endoftext|>", "\n\n" },
  },
  debounce = 500,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    suggest = "<C-Down>",
    suggest_next = "<leader><C-Down>",
  },
  ollama_url = "http://localhost:11434/api",
}

---@type BroOptions
local current_opts

---@param opts BroOptions
---@return BroOptions | boolean
local function set(opts)
  current_opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  return true
end

---@return BroOptions
local function get()
  return current_opts
end

return {
  get = get,
  set = set,
}
