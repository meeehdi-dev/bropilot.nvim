local llm = require("bropilot.llm")
local util = require("bropilot.util")

local M = {}

---@type Options
M.opts = {
  model = "codegemma:2b-code",
  prompt = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  debounce = 1000,
  auto_pull = true,
}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  callback = function()
    local row, col = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]

    if col < #current_line then
      return
    end

    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  callback = function()
    local row, col = util.get_cursor()
    local current_line = util.get_lines(row - 1, row)[1]

    if col < #current_line then
      return
    end

    local context_row = llm.get_context_row()

    if row == context_row then
      local context_line = llm.get_context_line()

      local current_suggestion = llm.get_suggestion()
      local suggestion_lines = vim.split(current_suggestion, "\n")

      local current_line_contains_suggestion = string.find(
        vim.pesc(context_line .. suggestion_lines[1]),
        vim.pesc(current_line)
      )

      if current_line_contains_suggestion then
        llm.render_suggestion()
        return
      end
    end

    llm.cancel()
    llm.clear()

    llm.suggest()
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  callback = function()
    llm.cancel()
    llm.clear()
  end,
})

---@param opts Options
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  vim.keymap.set("i", "<C-Right>", function()
    local suggestion = llm.get_suggestion()
    if suggestion == "" then
      local key = vim.api.nvim_replace_termcodes("<C-Right>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", true)
      return
    end
    llm.accept_word()
  end, { noremap = true })
  vim.keymap.set("i", "<S-Right>", function()
    local suggestion = llm.get_suggestion()
    if suggestion == "" then
      local key = vim.api.nvim_replace_termcodes("<S-Right>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", true)
      return
    end
    llm.accept_line()
  end, { noremap = true })
  vim.keymap.set("i", "<Tab>", function()
    local suggestion = llm.get_suggestion()
    if suggestion == "" then
      local key = vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", true)
      return
    end
    llm.accept_block()
  end, { noremap = true })

  -- setup options (model, prompt, keep_alive, params, etc...)
  llm.init(M.opts, function()
    local mode = vim.api.nvim_get_mode()

    if mode == "i" or mode == "r" then
      llm.suggest()
    end
  end)
end

return M
