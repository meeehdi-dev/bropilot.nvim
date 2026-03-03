local options = require("bropilot.options")
local util = require("bropilot.util")
local curl = require("plenary.curl")
local async = require("plenary.async")

---@param os string
---@param arch string
---@return string
local function get_binary_name(os, arch)
  return "llm-language-server-" .. os .. "-" .. arch
end

---@param name string
---@param version string
---@return string
local function get_download_url(name, version)
  return "https://github.com/meeehdi-dev/llm-language-server/releases/download/"
    .. version
    .. "/"
    .. name
    .. ".zip"
end

---@param cb fun(cmd: string[])
local function init(cb)
  local opts = options.get()

  if opts.ls_cmd then
    cb(opts.ls_cmd)
    return
  end

  local os_uname = vim.uv.os_uname()
  local os = string.lower(os_uname.sysname)
  local arch = string.lower(os_uname.machine)

  local version = opts.ls_version

  local binary_name = get_binary_name(os, arch)
  local binary_zip = binary_name .. "-" .. version .. ".zip"
  local download_url = get_download_url(binary_name, version)

  local binary_directory_path = vim.fn.stdpath("data") .. "/bropilot/bin"
  vim.fn.mkdir(binary_directory_path, "p")

  local binary_zip_path = binary_directory_path .. "/" .. binary_zip
  local binary_path = binary_directory_path
    .. "/llm-language-server-"
    .. version

  if vim.fn.executable(binary_path) == 1 then
    cb({ binary_path })
    return
  end

  local download_progress = util.get_progress_handle(
    "Downloading " .. binary_name .. "-" .. version .. ")..."
  )

  curl.get(download_url, {
    output = binary_zip_path,
    callback = function(out)
      util.finish_progress(download_progress)

      if out.exit ~= 0 then
        vim.notify(
          "Failed to download llm-language-server",
          vim.log.levels.ERROR
        )
        return
      end

      async.util.scheduler(function()
        local unzip_res = vim.fn.system(
          "unzip -o " .. binary_zip_path .. " -d " .. binary_directory_path
        )

        if vim.v.shell_error ~= 0 then
          vim.notify(
            "Failed to unzip llm-language-server: " .. unzip_res,
            vim.log.levels.ERROR
          )
          return
        end

        local extracted_path = binary_directory_path .. "/llm-language-server"
        local ok, err = vim.uv.fs_rename(extracted_path, binary_path)
        if not ok then
          vim.notify(
            "Failed to rename llm-language-server binary: " .. (err or ""),
            vim.log.levels.ERROR
          )
          return
        end

        vim.fn.delete(binary_zip_path)

        -- Ensure it is executable
        vim.fn.system("chmod +x " .. binary_path)

        cb({ binary_path })
      end)
    end,
  })
end

return {
  init = init,
}
