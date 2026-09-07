local M = {}

--- Fast check if a file exists and is readable using libuv
--- @param path string
--- @return boolean
function M.is_readable(path)
  if not path or path == "" then
    return false
  end
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

--- Check if a filepath is located within a directory
--- @param filepath string
--- @param dir string|nil
--- @return boolean
function M.is_under_dir(filepath, dir)
  if not filepath or filepath == "" then
    return false
  end
  dir = dir or vim.fn.getcwd()
  local norm_dir = vim.fs.normalize(dir)
  if not norm_dir:match("/$") then
    norm_dir = norm_dir .. "/"
  end
  local norm_file = vim.fs.normalize(vim.fn.fnamemodify(filepath, ":p"))
  if norm_file:sub(1, #norm_dir) == norm_dir then
    return true
  end

  local real_dir = vim.uv.fs_realpath(dir)
  local real_file = vim.uv.fs_realpath(filepath)
  if real_dir and real_file then
    real_dir = vim.fs.normalize(real_dir)
    if not real_dir:match("/$") then
      real_dir = real_dir .. "/"
    end
    real_file = vim.fs.normalize(real_file)
    if real_file:sub(1, #real_dir) == real_dir then
      return true
    end
  end

  local rel = vim.fs.relpath(dir, filepath)
  if rel and not rel:match("^%.%.") and not rel:match("^/") then
    return true
  end

  return false
end

--- Format path into clean filename and directory components
--- @param filepath string
--- @param cwd string|nil
--- @return string filename, string dir
function M.split_path(filepath, cwd)
  cwd = cwd or vim.fn.getcwd()

  -- Check if file is inside current working directory
  local rel = vim.fs.relpath(cwd, filepath)
  if rel then
    local dir = vim.fs.dirname(rel)
    local name = vim.fs.basename(rel)
    if dir == "." then
      return name, "./"
    else
      return name, dir .. "/"
    end
  end

  -- File is outside cwd: shorten HOME to ~
  local home = os.getenv("HOME")
  local display_path = filepath
  if home and filepath:sub(1, #home) == home then
    display_path = "~" .. filepath:sub(#home + 1)
  end

  local dir = vim.fs.dirname(display_path)
  local name = vim.fs.basename(display_path)
  if dir == "." or dir == "~" then
    return name, dir .. "/"
  end
  return name, dir .. "/"
end

--- Get icon and highlight group for a file
--- @param filepath string
--- @param show_icons boolean|nil
--- @return string icon, string hl_group
function M.get_file_icon(filepath, show_icons)
  if show_icons == false then
    return "", ""
  end

  local filename = vim.fs.basename(filepath)
  local extension = vim.fn.fnamemodify(filename, ":e")

  -- 1. Try mini.icons
  if package.loaded["mini.icons"] then
    local icon, hl = require("mini.icons").get("file", filename)
    if icon then
      return icon, hl or "StartinatorMruIcon"
    end
  end

  -- 2. Try nvim-web-devicons
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local icon, hl = devicons.get_icon(filename, extension, { default = true })
    if icon then
      return icon, hl or "StartinatorMruIcon"
    end
  end

  -- Fallback icon
  return "󰈔", "StartinatorMruIcon"
end

--- Setup highlight groups from configuration
--- @param hl_map table
function M.setup_highlights(hl_map)
  for name, def in pairs(hl_map or {}) do
    local group = name:match("^Startinator") and name or ("Startinator" .. name)
    local opts = vim.tbl_extend("force", { default = true }, def)
    vim.api.nvim_set_hl(0, group, opts)
  end
end

--- Get clean time-of-day greeting
--- @return string
function M.get_greeting()
  local hour = tonumber(os.date("%H"))
  if hour >= 5 and hour < 12 then
    return "Good morning"
  elseif hour >= 12 and hour < 18 then
    return "Good afternoon"
  else
    return "Good evening"
  end
end

--- Truncate string to max width with ellipsis
--- @param str string
--- @param max_len number
--- @return string
function M.truncate(str, max_len)
  if #str > max_len and max_len > 3 then
    return str:sub(1, max_len - 3) .. "..."
  end
  return str
end

return M
