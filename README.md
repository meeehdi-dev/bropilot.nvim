# Bropilot.nvim

Bropilot is a [GitHub Copilot](https://github.com/github/copilot.vim) alternative that takes advantage of local LLMs through [Ollama](https://ollama.com/)'s API.

Current working models:
- deepseek-coder (smallest and fastest)
- deepseek-coder-v2
- starcoder2
- codellama
- ~~codegemma~~ (doesn't seem to work anymore... https://github.com/ollama/ollama/issues/4806)


![image](https://github.com/meeehdi-dev/bropilot.nvim/assets/3422399/3a576c3d-7215-46cc-bfd5-150f33986996)


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

- `auto_suggest` is a boolean that enables automatic debounced suggestions
- `model` is a string (e.g. "codellama:7b-code" or "codegemma:2b-code")
- `model_params` is an optional table defining model params as per [Ollama API params](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values)
- `prompt` is a table defining the prefix, suffix and middle keywords for FIM
- `debounce` is a number in milliseconds
- `keymap` is a table to set the different keymap shortcuts

```lua
require('bropilot').setup({
  auto_suggest = false,
  model = "deepseek-coder:1.3b-base",
  model_params = {
    num_ctx = 4096, -- smaller ctx for faster suggestions (max is 16384 for this model)
    num_predict = -2,
    temperature = 0.2,
    top_p = 0.95,
  },
  -- model_params = {
  --   mirostat = 0,
  --   mirostat_eta = 0.1,
  --   mirostat_tau = 5.0,
  --   num_ctx = 2048,
  --   repeat_last_n = 64,
  --   repeat_penalty = 1.1,
  --   temperature = 0.8,
  --   seed = 0,
  --   stop = {},
  --   tfs_z = 1,
  --   num_predict = 128,
  --   top_k = 40,
  --   top_p = 0.9,
  --   min_p = 0.0,
  -- },
  prompt = {
    prefix = "<｜fim▁begin｜>",
    suffix = "<｜fim▁hole｜>",
    middle = "<｜fim▁end｜>",
  },
  debounce = 100, -- careful with this setting when auto_suggest is enabled, can lead to curl jobs overload
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
    suggest = "<C-Down>",
  },
  ollama_url = "http://localhost:11434/api",
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
      "j-hui/fidget.nvim",
    },
    config = true, -- setup with default options
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    event = "VeryLazy", -- preload model on start
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim",
    },
    opts = {
      auto_suggest = true,
      model = "starcoder2:3b",
      prompt = { -- FIM prompt for starcoder2
        prefix = "<fim_prefix>",
        suffix = "<fim_suffix>",
        middle = "<fim_middle>",
      },
      debounce = 500,
      keymap = {
        accept_line = "<M-Right>",
      },
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
  }
```
