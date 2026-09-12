local M = {}

local uv = vim.uv or vim.loop

--- Fast check if a file exists and is readable
---@param path string
---@return boolean
function M.is_readable(path)
  if not path or path == "" then
    return false
  end
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

--- Check if a filepath is located within a directory
---@param filepath string
---@param dir string|nil
---@return boolean
function M.is_under_dir(filepath, dir)
  if not filepath or filepath == "" then
    return false
  end
  dir = dir or vim.fn.getcwd()
  local rel = vim.fs.relpath(dir, filepath)
  return rel ~= nil and not rel:match("^%.%.") and not rel:match("^/")
end

--- Truncate string to max display width with an ellipsis
---@param str string
---@param max_w number
---@return string
function M.truncate(str, max_w)
  if vim.fn.strdisplaywidth(str) <= max_w or max_w < 4 then
    return str
  end
  local chars = vim.fn.strchars(str)
  for i = chars, 1, -1 do
    local sub = vim.fn.strcharpart(str, 0, i) .. "…"
    if vim.fn.strdisplaywidth(sub) <= max_w then
      return sub
    end
  end
  return "…"
end

--- Get icon and highlight group for a file
---@param filepath string
---@param show_icons boolean|nil
---@return string icon, string hl_group
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

  return "󰈔", "StartinatorMruIcon"
end

--- Generate a standardized section divider line
---@param title string
---@param width number
---@return table chunks Array of { text, hl }
function M.divider(title, width)
  local prefix = "─ " .. title .. " "
  local prefix_w = vim.fn.strdisplaywidth(prefix)
  local rule_w = math.max(2, width - prefix_w)
  return {
    { prefix, "StartinatorSectionTitle" },
    { string.rep("─", rule_w), "StartinatorSectionRule" },
  }
end

--- Align left and right chunk lists to fill target width
---@param left table Array of { text, hl }
---@param right table Array of { text, hl }
---@param width number Target block width
---@return table chunks Combined array of chunks with padding
function M.align_row(left, right, width)
  local left_w = 0
  for _, c in ipairs(left) do
    left_w = left_w + vim.fn.strdisplaywidth(c[1] or "")
  end

  local right_w = 0
  for _, c in ipairs(right) do
    right_w = right_w + vim.fn.strdisplaywidth(c[1] or "")
  end

  local pad = math.max(2, width - left_w - right_w)
  local row = {}

  for _, c in ipairs(left) do
    table.insert(row, c)
  end
  table.insert(row, { string.rep(" ", pad), nil })
  for _, c in ipairs(right) do
    table.insert(row, c)
  end

  return row
end

--- Setup highlight groups from configuration
---@param hl_map table<string, table>
function M.setup_highlights(hl_map)
  for name, def in pairs(hl_map or {}) do
    local group = name:match("^Startinator") and name or ("Startinator" .. name)
    vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", { default = true }, def))
  end
end

--- Get clean time-of-day greeting
---@return string
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

return M
