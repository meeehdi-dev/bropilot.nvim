# Bropilot.nvim

Bropilot is a GitHub Copilot alternative that takes advantage of local LLMs through Ollama's API.

Current working models:
- codellama (7b & 13b)
- codegemma (2b & 7b)
- starcoder2 (3b & 7b)


![image](https://github.com/meeehdi-dev/bropilot.nvim/assets/3422399/ff18e6c8-691f-48ea-8f71-5f187a35b89a)



## Configuration

Here is the default configuration.

- `` is a string WIP.

```lua
require('bropilot').setup({
  -- WIP
})
```

## Usage

Install and configure using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
  {
    'meeehdi-dev/bropilot.nvim',
    event = "InsertEnter",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim", -- optional
    },
    config = true, -- setup with default options
    -- does nothing if no keys
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    event = "InsertEnter",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim", -- optional
    },
    opts = {
      -- WIP
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
    keys = {
      {
        "<C-Right>",
        function()
          require("bropilot").accept_line()
        end,
        mode = "i",
      },
      {
        "<Tab>",
        function()
          require("bropilot").accept_block()
        end,
        mode = "i",
      },
    },
  }
```

## Roadmap

- [x] show suggestion as virtual text
- [x] accept line
- [x] accept block
- [x] progress while suggesting
- [ ] cleanup current code
- [ ] fix: remove additional newlines at end of suggestion
- [ ] fix: sometimes the suggestion is not cancelled even tho inserted text doesn't match
- [ ] fix: sometimes the pid is already killed => improve async processes handling
- [ ] wait for model to be ready before trying to suggest (does ollama api provide that info?)
- [ ] keep subsequent suggestions in memory (behind option? full suggestions might be heavy on memory)
- [ ] custom init options
  - [ ] model
  - [ ] prompt (assert if unknown model)
  - [ ] suggest debounce time
  - [ ] show progress
  - [ ] ollama params
- [ ] check if model is listed in ollama api
- [ ] pull model if not listed (behind option)
- [ ] replace unix sleep with async job
- [ ] accept word
- [ ] commands (might need additional model -instruct?-)
  - [ ] describe
  - [ ] refactor
  - [ ] comment
  - [ ] chat
  - [ ] commit msg (using git diff --staged + concentional commit rules)
- [ ] add more context to prompt
  - [ ] opened splits
  - [ ] opened tabs
  - [ ] lsp info (arg types, return types)
  - [ ] imported files outlines (with lsp info also?)
