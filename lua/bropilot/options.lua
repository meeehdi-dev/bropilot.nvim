---@alias KeymapParams { accept_word: string, accept_line: string, accept_block: string, suggest: string }
---@alias BroOptions { api_key: string, auto_suggest?: boolean, excluded_filetypes?: string[], model: string, debounce: number, keymap: KeymapParams }

---@type BroOptions
local default_opts = {
  api_key = "<CODESTRAL_API_KEY>",
  auto_suggest = true,
  excluded_filetypes = {},
  debounce = 500,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    suggest = "<C-Down>",
  },
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
