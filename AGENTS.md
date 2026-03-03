# Bropilot.nvim - AI Agent Guidelines

This document provides instructions and guidelines for AI agents (like Copilot, Cursor, or other coding assistants) operating within the `bropilot.nvim` repository.

## 1. Project Overview
`bropilot.nvim` is a Neovim plugin written in Lua. It acts as a GitHub Copilot alternative supporting multiple providers, including local LLMs via Ollama, Codestral, and Copilot LSP. It relies on `llm-language-server` in the background for managing file states and completions.

## 2. Build, Lint, and Test Commands

### Linting and Formatting
The project uses `stylua` for formatting. Always ensure your changes are formatted according to the `stylua.toml` configuration before completing a task.
- **Check formatting:** `stylua --check .`
- **Format all files:** `stylua .`
- **Format a single file:** `stylua lua/bropilot/filename.lua`

### Testing
There is currently no comprehensive test suite (e.g., `tests/` directory is absent). However, the project depends on `plenary.nvim`. If tests are introduced in the future, they should use Plenary's busted framework:
- **Run all tests (if added):** `nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"`
- **Run a single test file (if added):** `nvim --headless -c "PlenaryBustedFile tests/test_file_spec.lua"`

*Note: For now, verify functionality by loading the plugin in a local Neovim instance and testing the specific feature manually.*

## 3. Code Style Guidelines

### 3.1 Formatting (Stylua Rules)
- **Indentation:** 2 spaces.
- **Line Length:** 80 characters.
- **Quotes:** Prefer double quotes (`"`).
- **Parentheses:** Always use parentheses for function calls (e.g., `print("hello")` instead of `print "hello"`).
- **Line Endings:** Unix (`\n`).
- **Statements:** Never collapse simple statements into a single line.

### 3.2 Types and Annotations
- Use **EmmyLua** annotations extensively for type checking and documentation.
- Annotate functions with `---@param` and `---@return`.
- Example:
  ```lua
  ---@param buf number The buffer ID
  ---@return boolean true if in workspace, false otherwise
  local function in_workspace(buf)
    -- implementation
  end
  ```
- Define classes/tables using `---@class`, `---@field`, etc. (e.g., `---@param opts BroOptions`).

### 3.3 Imports and Structure
- Module paths start with `bropilot.`, e.g., `require("bropilot.options")`.
- Store required modules in local variables at the top of the file:
  ```lua
  local suggestion = require("bropilot.suggestion")
  local util = require("bropilot.util")
  ```
- Do not use global variables (`_G`) unless absolutely necessary. Prefix everything with `local`.
- Return a table at the end of the module file:
  ```lua
  return {
    setup = setup,
    -- exported functions
  }
  ```

### 3.4 Neovim API Usage
- Use `vim.api` and `vim.fn` instead of deprecated or legacy Neovim commands.
- For autocommands, use `vim.api.nvim_create_autocmd` and `vim.api.nvim_create_augroup`.
- Example of augroup usage:
  ```lua
  local bro_group = vim.api.nvim_create_augroup("bropilot", {})
  vim.api.nvim_create_autocmd({ "InsertEnter" }, {
    group = bro_group,
    callback = function() ... end,
  })
  ```

### 3.5 Error Handling and Notifications
- Do not use `print()` for warnings or errors.
- Use `vim.notify` with appropriate log levels.
  ```lua
  vim.notify("Invalid bropilot configuration", vim.log.levels.ERROR)
  vim.notify("Operation successful", vim.log.levels.INFO)
  ```
- Fail gracefully. If a configuration is wrong, log the error and `return` early rather than throwing a hard Lua error that disrupts the user's editing experience.

### 3.6 Naming Conventions
- **Variables and Functions:** `snake_case` (e.g., `auto_suggest`, `in_workspace`).
- **Files/Modules:** `kebab-case` or `snake_case` (e.g., `llm-ls.lua`, `virtual-text.lua`).
- **Constants:** `UPPER_SNAKE_CASE` (e.g., `DEFAULT_TIMEOUT`).

### 3.7 General Guidelines
- Check the `options.lua` file before adding new configuration properties.
- When working with UI (like suggestions or virtual text), reference existing implementations in `suggestion.lua` or `virtual-text.lua`.
- Never commit secrets or API keys. Ensure users supply their own keys via configuration (e.g., `opts.api_key` for Codestral).
- Strive for minimal latency. LLM interactions should be asynchronous (using plenary's job/curl or neovim's `uv` library if applicable) to avoid blocking the main Neovim UI thread.
