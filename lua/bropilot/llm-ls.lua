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

  local ext = ""
  if os == "windows" then
    ext = ".exe"
  end

  local binary_zip_path = binary_directory_path .. "/" .. binary_zip
  local binary_path = binary_directory_path
    .. "/llm-language-server-"
    .. version
    .. ext

  if vim.fn.executable(binary_path) == 1 then
    cb({ binary_path })
    return
  end

  local download_progress = util.get_progress_handle(
    "Downloading " .. binary_name .. "-" .. version .. ")..."
  )

  curl.get(download_url, {
    output = binary_zip_path,
    callback = function()
      util.finish_progress(download_progress)

      -- TODO: error handling

      async.util.scheduler(function()
        vim.fn.system(
          "unzip -o " .. binary_zip_path .. " -d " .. binary_directory_path
        )
        vim.fn.system(
          "mv "
            .. binary_directory_path
            .. "/llm-language-server "
            .. binary_path
        )
        -- vim.fn.system("rm " .. binary_zip_path)

        cb({ binary_path })
      end)
    end,
  })
end

return {
  init = init,
}
