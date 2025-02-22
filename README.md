# Bropilot.nvim


Bropilot is a [GitHub Copilot](https://github.com/github/copilot.vim) alternative that takes advantage of local LLMs through [Ollama](https://ollama.com/)'s API.

Current working models:
- qwen2.5-coder
- deepseek-coder
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
- `excluded_filetypes` is an array of filetypes ignored by the `auto_suggest` option (https://github.com/meeehdi-dev/bropilot.nvim/pull/1)
- `model` is a string (e.g. "codellama:7b-code" or "codegemma:2b-code")
- `model_params` is an optional table defining model params as per [Ollama API params](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values)
- `prompt` is a table defining the `prefix`, `suffix` and `middle` keywords for FIM
- `debounce` is a number in milliseconds (this value gradually increases as long as curl does not respond to avoid overload issues)
- `keymap` is a table to set the different keymap shortcuts *(not using lazy keys to allow fallback to default behavior when suggestions are not active)*

```lua
require('bropilot').setup({
  auto_suggest = true,
  excluded_filetypes = {},
  model = "qwen2.5-coder:0.5b-base",
  model_params = {
    num_ctx = 32768,
    num_ctx = 8192,
    num_predict = -2,
    temperature = 0.2,
    top_p = 0.95,
    stop = { "<|fim_pad|>", "<|endoftext|>" },
  },
  prompt = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  debounce = 500,
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
