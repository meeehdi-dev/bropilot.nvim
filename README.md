# Bropilot.nvim

Bropilot is a [GitHub Copilot](https://github.com/github/copilot.vim) alternative that takes advantage of local LLMs through [Ollama](https://ollama.com/)'s API.

Current working models:
- codellama (7b & 13b)
- codegemma (2b & 7b)
- starcoder2 (3b & 7b)


![image](https://github.com/meeehdi-dev/bropilot.nvim/assets/3422399/ff18e6c8-691f-48ea-8f71-5f187a35b89a)



## Setup

You need to have [Ollama](https://ollama.com/) installed and running for bro to work.
[Official download link](https://ollama.com/download)

For Linux:
```sh
curl -fsSL https://ollama.com/install.sh | sh
# And check that the service is running
systemctl status ollama
```

## Configuration

Here is the default configuration.

- `model` is a string enum ("codellama" | "codegemma" | "starcoder2").
- `variant` is a string (e.g. "7b-code").
- `debounce` is a number in milliseconds (e.g. "7b-code").

```lua
require('bropilot').setup({
  model = "codellama",
  variant = "7b-code",
  debounce = 100
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
    keys = {
      {
        "<Tab>",
        function()
          require("bropilot").accept_block()
        end,
        mode = "i",
      },
    },
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    event = "InsertEnter",
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- "j-hui/fidget.nvim", -- optional
    },
    opts = {
      model = "codellama",
      variant = "7b-code",
      debounce = 100,
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
- [x] cleanup current code
- [x] skip suggestion if text after cursor (except if just moving?)
- [x] fix: accepting line resets suggestion
- [x] fix: remove additional newlines at end of suggestion
- [x] fix: sometimes the suggestion is not cancelled even tho inserted text doesn't match
- [ ] fix: partial accept + newline => doesn't clear suggestion
- [ ] fix: sometimes the pid is already killed => TODO: improve all async processes handling
- [ ] some lua callbacks in async process, need to use scheduler (util function?)
- [x] wait for model to be ready before trying to suggest (does ollama api provide that info? -> using preload)
- [ ] check that suggestion is created after model finishes preload
- [ ] notify on ollama api errors
- [x] keep subsequent suggestions in memory
- [ ] accepting block resets suggestions
- [ ] custom init options
  - [x] model
  - [x] variant
  - [ ] prompt (assert if unknown model)
  - [x] debounce time
  - [ ] show progress
  - [ ] keep all current suggestions in memory (option to keep only n blocks)
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
