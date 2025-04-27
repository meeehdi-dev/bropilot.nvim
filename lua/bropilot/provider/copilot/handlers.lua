return {
  ["didChangeStatus"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("didChangeStatus")
    -- vim.print(res)
  end,
  ["statusNotification"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("statusNotification")
    -- vim.print(res)
  end,
  ["workspace/configuration"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("workspace/configuration")
    -- vim.print(res)
    return true
  end,
  ["window/logMessage"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    -- vim.notify("window/logMessage")
    -- vim.print(res)
    vim.notify(res.message, vim.log.levels[res.type])
  end,
  ["window/showDocument"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("window/showDocument")
    -- vim.print(res)
  end,
  ["conversation/preconditionsNotification"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("conversation/preconditionsNotification")
    -- vim.print(res)
  end,
  ["featureFlagsNotification"] = function(err, res, ctx)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    vim.notify("featureFlagsNotification")
    -- vim.print(res)
  end,
}
