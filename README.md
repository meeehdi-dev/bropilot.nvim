# Bropilot.nvim

<p align="center">
  <img src="https://github.com/meeehdi-dev/bropilot.nvim/assets/3422399/3a576c3d-7215-46cc-bfd5-150f33986996" />
</p>

Bropilot is a [GitHub Copilot](https://github.com/github/copilot.vim) alternative that can handle multiple providers, with the main advantage of being able to use local LLMs through [Ollama](https://ollama.com/)'s API.

In the background, this plugin downloads and runs [llm-language-server](https://github.com/meeehdi-dev/llm-language-server), a language server used to keep track of the currently edited files states, and communicates directly with the LLM of your choice.

Any FIM-compatible model works but here's a list of tested ones:
- qwen2.5-coder
- deepseek-coder
- deepseek-coder-v2
- starcoder2
- codellama

> Thanks to [@hieutran21198](https://github.com/hieutran21198), here's a [list of most compatible models and their associated FIM tokens](https://github.com/hieutran21198/ai-agent-models) for easier configuration

Other than Ollama models, you can use a couple other online providers:
- Codestral (via Mistral API)
- Copilot (via Github Copilot LSP)

## Copilot

### Signing in

When copilot is initialized for the first time, it'll ask you to sign in by generating a unique code that you'll have to paste in your browser.

### Next edit suggestions

<p align="center">
  <img src="https://github.com/user-attachments/assets/f2faa927-b753-4df3-bfcf-7b7c78724a5a" />
</p>

Thanks to Github's copilot LSP and the work of [@Tris203](https://github.com/tris203) and [@Xuyuanp](https://github.com/Xuyuanp) on https://github.com/copilotlsp-nvim/copilot-lsp, if you use copilot as the provider, whenever you accept a suggestion, a request is sent to the LSP to ask for next edit suggestions.

You can also set a keymap to force a request.

⚠️ Please note that it is very experimental at the moment.

## Setup

If you want to use local models, you'll need to have [Ollama](https://ollama.com/) installed and running for bro to work.
[Official download link](https://ollama.com/download)

For Linux:
```sh
curl -fsSL https://ollama.com/install.sh | sh
# And check that the service is running
systemctl status ollama
```

## Configuration

Here is the default configuration.

- `provider` is a string defining the provider to use (`ollama`, `codestral` and `copilot` are supported)
- `ls_version` is a string defining the version of [llm-language-server](https://github.com/meeehdi-dev/llm-language-server)
- `api_key` is a string defining the API key to use for the `codestral` provider
- `auto_suggest` is a boolean that enables automatic debounced suggestions
- `excluded_filetypes` is an array of filetypes ignored by the `auto_suggest` option (https://github.com/meeehdi-dev/bropilot.nvim/pull/1)
- `model` is the name of the model as listed with `ollama ls` (e.g. "codellama:7b-code" or "codegemma:2b-code")
- `model_params` is an optional table defining model params as per [Ollama API params](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values)
- `debounce` is a number in milliseconds (this value gradually increases as long as the request does not respond on time, to avoid network overload issues)
- `keymap` is a table to set the different keymap shortcuts *(not using lazy keys to allow fallback to default behavior when suggestions are not active)*

```lua
require('bropilot').setup({
  provider = "ollama",
  auto_suggest = true,
  excluded_filetypes = {},
  model = "qwen2.5-coder:0.5b",
  model_params = {
    num_ctx = 32768,
    num_predict = -2,
    temperature = 0.2,
    top_p = 0.95,
    stop = { "<|fim_pad|>", "<|endoftext|>", "\n\n" },
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
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim",
    },
    config = true, -- setup with default options
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim",
    },
    opts = {
      auto_suggest = true,
      model = "starcoder2:3b",
      debounce = 500,
      keymap = {
        accept_line = "<M-Right>",
      },
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim",
    },
    opts = {
      provider = "codestral",
      api_key = "<CODESTRAL_API_KEY>",
      auto_suggest = false,
      debounce = 1,
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
  }
  -- or
  {
    'meeehdi-dev/bropilot.nvim',
    dependencies = {
      "nvim-lua/plenary.nvim",
      "j-hui/fidget.nvim",
    },
    opts = {
      provider = "copilot",
      debounce = 1000,
      keymap = {
        suggest_next = "<M-Down>",
      },
    },
    config = function (_, opts)
        require("bropilot").setup(opts)
    end,
  }
```
