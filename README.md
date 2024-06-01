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

- `model` is a string (e.g. "codellama:7b-code" or "codegemma:2b-code")
- `prompt` is an object defining the prefix, suffix and middle keywords for FIM
- `debounce` is a number in milliseconds
- `auto_pull` is a boolean that allows bro to pull the model if not listed in ollama api

```lua
require('bropilot').setup({
  model = "codegemma:2b-code",
  prompt = { -- FIM prompt for codegemma
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  debounce = 1000,
  auto_pull = true,
})
```

## Usage

Install and configure using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
  {
    'meeehdi-dev/bropilot.nvim',
    event = "VeryLazy", -- preload model on start
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
    event = "InsertEnter", -- preload model on insert start
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- "j-hui/fidget.nvim", -- optional
    },
    opts = {
      model = "starcoder2:3b",
      prompt = { -- FIM prompt for starcoder2
        prefix = "<fim_prefix>",
        suffix = "<fim_suffix>",
        middle = "<fim_middle>",
      },
      debounce = 500,
      auto_pull = false,
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
    keys = {
      -- Soon
      {
        "<C-Right>",
        function()
          require("bropilot").accept_word()
        end,
        mode = "i",
      },
      {
        "<M-Right>",
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
- [x] improve init
- [x] rewrite async handling and use callbacks to avoid timing problems
- [x] rejoin model & tag
- [x] fix: partial accept + newline => doesn't clear suggestion
- [x] fix: sometimes the pid is already killed
- [ ] fix: notify non existent model
- [x] some lua callbacks in async process, need to use scheduler (async util function)
- [x] wait for model to be ready before trying to suggest (does ollama api provide that info? -> using preload)
- [x] check that suggestion is created after model finishes preload
- [ ] notify on ollama api errors
- [x] keep subsequent suggestions in memory
- [x] accepting block resets suggestions
- [x] refactor everything
- [x] fix: keep same suggestion when partially accepting
- [ ] custom init options
  - [x] model
  - [x] ~~tag~~
  - [x] prompt (assert if unknown model)
  - [x] debounce time
  - [x] pull model if missing
  - [x] show progress
  - [ ] keep all current suggestions in memory (option to keep only n blocks)
  - [ ] ollama params
- [x] check if model is listed in ollama api
- [x] pull model if not listed (behind option)
- [x] replace unix sleep with async job
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
