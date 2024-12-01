local presets = {
  ["qwen2.5-coder"] = {
    model_params = {
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
  },
  -- TODO: add other model presets
}

return presets
