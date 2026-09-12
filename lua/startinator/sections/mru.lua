local utils = require("startinator.utils")

local M = {}

--- Filter v:oldfiles according to configuration
---@param opts table
---@return table list of valid file paths
local function get_mru_files(opts)
  local oldfiles = vim.v.oldfiles or {}
  local filtered = {}
  local limit = opts.limit or 5
  local cwd = vim.fn.getcwd()
  local cwd_only = opts.cwd_only ~= false
  local seen = {}

  for _, filepath in ipairs(oldfiles) do
    if #filtered >= limit then
      break
    end

    if type(filepath) == "string" and filepath ~= "" then
      local abs_path = vim.fs.normalize(vim.fn.fnamemodify(filepath, ":p"))
      if not seen[abs_path] and utils.is_readable(abs_path) then
        local skip = false

        if opts.ignore then
          for _, pattern in ipairs(opts.ignore) do
            if filepath:find(pattern) or abs_path:find(pattern) then
              skip = true
              break
            end
          end
        end

        if not skip and cwd_only and not utils.is_under_dir(abs_path, cwd) then
          skip = true
        end

        if not skip then
          seen[abs_path] = true
          table.insert(filtered, abs_path)
        end
      end
    end
  end

  return filtered
end

--- Render MRU section
---@param config table
---@return table
function M.render(config)
  local opts = config.mru
  if not opts or not opts.enabled then
    return { lines = {}, items = {} }
  end

  local files = get_mru_files(opts)
  if #files == 0 then
    return { lines = {}, items = {} }
  end

  local lines = {}
  local items = {}
  local width = config._resolved_width or config.width or 46
  local cwd = vim.fn.getcwd()
  local home = os.getenv("HOME")
  local show_icons = opts.show_icons ~= false and config.show_icons ~= false
  local sel_str, sel_hl = utils.get_selector(config)
  local sel_w = vim.fn.strdisplaywidth(sel_str)

  -- Section divider
  if opts.title and opts.title ~= "" then
    table.insert(lines, utils.divider(opts.title, width))
  end

  for idx, filepath in ipairs(files) do
    local key_num = tostring(idx)
    local key_w = vim.fn.strdisplaywidth(key_num)

    -- File icon
    local icon_str = ""
    local icon_hl = "StartinatorMruIcon"
    if show_icons then
      local ic, hl = utils.get_file_icon(filepath, true)
      if ic and ic ~= "" then
        icon_str = ic .. "  "
        icon_hl = hl or icon_hl
      end
    end
    local icon_w = vim.fn.strdisplaywidth(icon_str)

    -- Split path into directory prefix and filename
    local dir_str = ""
    local name = vim.fs.basename(filepath)

    local rel = vim.fs.relpath(cwd, filepath)
    if rel and not rel:find("^%.%./") then
      local d = vim.fs.dirname(rel)
      if d ~= "." then
        dir_str = d .. "/"
      end
    else
      local display = filepath
      if home and filepath:sub(1, #home) == home then
        display = "~" .. filepath:sub(#home + 1)
      end
      local d = vim.fs.dirname(display)
      dir_str = (d == "~" or d == ".") and "~/" or (d .. "/")
    end

    local avail_w = width - sel_w - icon_w - key_w - 2
    local name_w = vim.fn.strdisplaywidth(name)
    local dir_w = vim.fn.strdisplaywidth(dir_str)

    -- Left-truncate directory if path exceeds available width
    if dir_w + name_w > avail_w then
      local max_dir_w = avail_w - name_w
      if max_dir_w >= 5 then
        local keep = max_dir_w - 2
        local cut = dir_str:sub(#dir_str - keep + 1)
        local slash = cut:find("/")
        dir_str = "…/" .. (slash and cut:sub(slash + 1) or cut)
      else
        dir_str = ""
        if name_w > avail_w then
          name = utils.truncate(name, avail_w)
        end
      end
    end

    local left = {}
    if sel_str ~= "" then
      table.insert(left, { sel_str, sel_hl })
    end
    if icon_str ~= "" then
      table.insert(left, { icon_str, icon_hl })
    end
    if dir_str ~= "" then
      table.insert(left, { dir_str, "StartinatorMruPath" })
    end
    table.insert(left, { name, "StartinatorMruFilename" })

    local right = {
      { key_num, "StartinatorMruIndex" },
    }

    table.insert(lines, utils.align_row(left, right, width))
    table.insert(items, {
      line_idx = #lines,
      key = key_num,
      action = function()
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      end,
      type = "mru",
      path = filepath,
      label = name,
    })
  end

  return {
    lines = lines,
    items = items,
  }
end

return M
