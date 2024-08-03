---@alias ModelParams { mirostat?: number, mirostat_eta?: number, mirostat_tau?: number, num_ctx?: number, repeat_last_n?: number, repeat_penalty?: number, temperature?: number, seed?: number, stop?: number[], tfs_z?: number, num_predict?: number, top_k?: number, top_p?: number }
---@alias ModelPrompt { prefix: string, suffix: string, middle: string }
---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, resuggest: string }
---@alias Options { model: string, model_params?: ModelParams, prompt: ModelPrompt, debounce: number, keymap: KeymapParams, ollama_url: string }

local M = {}

---@type Options
M.opts = {
  model = "codellama:7b-code",
  prompt = {
    prefix = "<PRE> ",
    suffix = " <SUF>",
    middle = " <MID>",
  },
  debounce = 500,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    resuggest = "<C-Down>",
  },
  ollama_url = "http://localhost:11434/api",
}

---@param opts Options
function M.set(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

---@return Options
function M.get()
  return M.opts
end

return M
