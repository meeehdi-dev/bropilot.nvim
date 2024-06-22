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
- `model_params` is an optional table defining model params as per [Ollama API params](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values)
- `prompt` is a table defining the prefix, suffix and middle keywords for FIM
- `debounce` is a number in milliseconds
- `auto_pull` is a boolean that allows bro to pull the model if not listed in ollama api
- `keymap` is a table to set the different keymap shortcuts

```lua
require('bropilot').setup({
  model = "codegemma:2b-code",
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
  -- },
  prompt = { -- FIM prompt for codegemma
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  debounce = 1000,
  auto_pull = true,
  keymap = {
    accept_word = "<C-Right>",
    accept_line = "<S-Right>",
    accept_block = "<Tab>",
  },
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
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    event = "VeryLazy", -- preload model on start
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
      keymap = {
        accept_line = "<M-Right>",
      },
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
  }
```
