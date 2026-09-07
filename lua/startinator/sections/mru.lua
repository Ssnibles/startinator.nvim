local utils = require("startinator.utils")

local M = {}

--- Filter v:oldfiles according to config
--- @param opts table
--- @return table list of valid filepaths
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

        if not skip and cwd_only then
          if not utils.is_under_dir(abs_path, cwd) then
            skip = true
          end
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

--- Render MRU section with single path and highlighted filename
--- @param config table
--- @return table
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
  local block_width = config._resolved_width or config.width or 46
  local cwd = vim.fn.getcwd()
  local home = os.getenv("HOME")
  local show_icons = opts.show_icons ~= false and config.show_icons ~= false

  -- Section Header Divider: ─ Recent ──────────────────────────
  if opts.title and opts.title ~= "" then
    local title_prefix = "─ " .. opts.title .. " "
    local title_w = vim.fn.strdisplaywidth(title_prefix)
    local rule_w = math.max(2, block_width - title_w)
    local rule_str = string.rep("─", rule_w)

    table.insert(lines, {
      { title_prefix, "StartinatorSectionTitle" },
      { rule_str, "StartinatorSectionRule" },
    })
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
    local name = ""

    local rel = vim.fs.relpath(cwd, filepath)
    if rel and not rel:find("^%.%./") then
      local d = vim.fs.dirname(rel)
      name = vim.fs.basename(rel)
      if d ~= "." then
        dir_str = d .. "/"
      end
    else
      local display = filepath
      if home and filepath:sub(1, #home) == home then
        display = "~" .. filepath:sub(#home + 1)
      end
      local d = vim.fs.dirname(display)
      name = vim.fs.basename(display)
      if d == "~" or d == "." then
        dir_str = "~/"
      else
        dir_str = d .. "/"
      end
    end

    local avail_w = block_width - icon_w - key_w - 2
    local name_w = vim.fn.strdisplaywidth(name)
    local dir_w = vim.fn.strdisplaywidth(dir_str)

    -- Left-truncate directory if path exceeds available width
    if dir_w + name_w > avail_w then
      local max_dir_w = avail_w - name_w
      if max_dir_w >= 5 then
        local keep_len = max_dir_w - 2
        local cut_dir = dir_str:sub(#dir_str - keep_len + 1)
        local slash = cut_dir:find("/")
        if slash and slash < #cut_dir - 2 then
          cut_dir = cut_dir:sub(slash + 1)
        end
        dir_str = "…/" .. cut_dir
        dir_w = vim.fn.strdisplaywidth(dir_str)
      else
        dir_str = ""
        dir_w = 0
        if name_w > avail_w then
          name = utils.truncate(name, avail_w)
          name_w = vim.fn.strdisplaywidth(name)
        end
      end
    end

    local pad_spaces = math.max(2, block_width - icon_w - dir_w - name_w - key_w)

    local line_chunks = {}
    if icon_str ~= "" then
      table.insert(line_chunks, { icon_str, icon_hl })
    end
    if dir_str ~= "" then
      table.insert(line_chunks, { dir_str, "StartinatorMruPath" })
    end
    table.insert(line_chunks, { name, "StartinatorMruFilename" })
    table.insert(line_chunks, { string.rep(" ", pad_spaces), nil })
    table.insert(line_chunks, { key_num, "StartinatorMruIndex" })

    table.insert(lines, line_chunks)

    local target_path = filepath
    table.insert(items, {
      line_idx = #lines,
      key = key_num,
      action = function()
        vim.cmd("edit " .. vim.fn.fnameescape(target_path))
      end,
      type = "mru",
      path = target_path,
      label = name,
    })
  end

  return {
    lines = lines,
    items = items,
  }
end

return M
