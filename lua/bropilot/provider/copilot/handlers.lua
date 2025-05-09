local debug_log = false

local lsp_log_type_map = {
  [1] = vim.log.levels.ERROR,
  [2] = vim.log.levels.WARN,
  [3] = vim.log.levels.INFO,
  [4] = nil, -- log
  [5] = vim.log.levels.DEBUG,
}

return {
  ["didChangeStatus"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    if debug_log then
      vim.notify("didChangeStatus")
      vim.print(res)
    end
  end,
  ["statusNotification"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    if debug_log then
      vim.notify("statusNotification")
      vim.print(res)
    end
  end,
  ["workspace/configuration"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    if debug_log then
      vim.notify("workspace/configuration")
      vim.print(res)
    end
    return true
  end,
  ["window/logMessage"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify(res.message, lsp_log_type_map[res.type])
  end,
  ["window/showDocument"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("window/showDocument", vim.log.levels.INFO)
  end,
  ["conversation/preconditionsNotification"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("conversation/preconditionsNotification")
  end,
  ["featureFlagsNotification"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("featureFlagsNotification", vim.log.levels.INFO)
  end,
}
