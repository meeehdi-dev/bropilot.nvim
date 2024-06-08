local util = require("bropilot.util")

local M = {}

function M.get_buffers_hover(cb)
  local buffers = vim.api.nvim_list_bufs()
  local count = 0
  local buffer_hover_tbl = {}
  for _, buf_id in ipairs(buffers) do
    if not vim.api.nvim_buf_is_loaded(buf_id) or vim.api.nvim_buf_get_name(buf_id) == "" then
      count = count + 1
    else
      M.get_buffer_hover(buf_id, function(line_hover)
        buffer_hover_tbl[buf_id] = line_hover
        count = count + 1
        if count >= #buffers then
          cb(buffer_hover_tbl)
        end
      end)
    end
  end
end

function M.get_buffer_hover(buf_id, cb)
  vim.lsp.buf_request(buf_id, "textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(0),
  }, function(err, symbols)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end

    local count = 0
    local line_hover_tbl = {}
    for _, symbol in pairs(symbols) do
      local line =
        util.get_lines(symbol.range.start.line, symbol.range.start.line + 1)[1]
      local character = string.find(line, symbol.name)

      M.get_symbol_hover(
        buf_id,
        symbol.range.start.line,
        character + #symbol.name - 1,
        function(hover)
          line_hover_tbl[symbol.range.start.line] = hover
          count = count + 1
          if count >= #symbols then
            cb(line_hover_tbl)
          end
        end
      )
    end
  end)
end

function M.get_symbol_hover(buf_id, line, character, cb)
  vim.lsp.buf_request(buf_id, "textDocument/hover", {
    textDocument = vim.lsp.util.make_text_document_params(0),
    position = {
      line = line,
      character = character,
    },
  }, function(err, response)
    if err ~= nil then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end

    cb(response.contents.value)
  end)
end

return M
