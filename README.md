-- ABOUT
Ollama-based code suggestion and completion, mimicking the behavior of GitHub Copilot

# Bropilot.nvim

Bropilot is a GitHub Copilot alternative that takes advantage local LLMs through Ollama's API.

The goal of this project is to provide a minimal and local-only solution to speed up development thanks to Ollama.


![TODO demo](TODO)


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
      "j-hui/fidget.nvim",
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
      "j-hui/fidget.nvim",
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

[x] show suggestion as virtual text
[x] accept line
[x] accept block
[] progress while suggesting
[] cleanup current code
[] keep subsequent suggestions in memory (behind option? full suggestions might be heavy on memory)
[] custom init options (+ assert prompt if unknown model)
[] check if model is listed in ollama api
[] pull model if not listed (behind option)
[] replace unix sleep with async job
[] accept word
[] commands (might need additional model -instruct?-)
  - [] describe
  - [] refactor
  - [] comment
  - [] chat
  - [] commit msg (using git diff --staged + concentional commit rules)
