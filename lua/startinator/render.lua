local utils = require("startinator.utils")

local M = {}

--- Custom section registry
M.sections = {}

--- Register a custom section renderer
---@param name string
---@param renderer table|function
function M.register_section(name, renderer)
  M.sections[name] = type(renderer) == "function" and { render = renderer } or renderer
end

--- Resolve highlight group name with Startinator prefix fallback
---@param hl string|nil
---@return string|nil
local function resolve_hl(hl)
  if not hl or hl == "" then
    return nil
  end
  if vim.fn.hlexists(hl) == 1 then
    return hl
  end
  local prefixed = "Startinator" .. hl
  if vim.fn.hlexists(prefixed) == 1 then
    return prefixed
  end
  return hl
end

--- Normalize a line definition into an array of { text, hl } chunks
---@param line_def any
---@return table chunks
local function normalize_line(line_def)
  if type(line_def) == "string" then
    return { { line_def, nil } }
  end

  if type(line_def) ~= "table" then
    return { { tostring(line_def or ""), nil } }
  end

  -- Single chunk: { "text", "hl" }
  if #line_def == 2 and type(line_def[1]) == "string" and (type(line_def[2]) == "string" or line_def[2] == nil) and line_def.text == nil then
    return { { line_def[1], resolve_hl(line_def[2]) } }
  end

  local chunks = {}
  for _, item in ipairs(line_def) do
    if type(item) == "string" then
      table.insert(chunks, { item, nil })
    elseif type(item) == "table" then
      local text = item.text or item[1] or ""
      local hl = resolve_hl(item.hl or item.hl_group or item[2])
      table.insert(chunks, { text, hl })
    end
  end

  return #chunks > 0 and chunks or { { "", nil } }
end

--- Resolve section handler from name, table, or function
---@param sec string|table|function
---@return table|nil
local function get_section_module(sec)
  if type(sec) == "function" then
    return { render = sec }
  elseif type(sec) == "table" and sec.render then
    return sec
  elseif type(sec) == "string" then
    if M.sections[sec] then
      return M.sections[sec]
    end
    local ok, mod = pcall(require, "startinator.sections." .. sec)
    if ok then
      return mod
    end
  end
  return nil
end

--- Render all configured sections and draw to the dashboard buffer
---@param buf number
---@param win number
---@param config table
function M.draw(buf, win, config)
  utils.setup_highlights(config.highlights or {})

  local win_w = vim.api.nvim_win_get_width(win)
  local target_w = config.width or 46
  local block_width = math.min(target_w, math.max(20, win_w - 4))
  config._resolved_width = block_width

  local all_lines_chunks = {}
  local legacy_highlights = {}
  local interactive_items = {}
  local current_offset = 0

  -- 1. Gather all section outputs
  for _, sec in ipairs(config.sections or {}) do
    local sec_module = get_section_module(sec)
    if sec_module then
      local res = sec_module.render(config)
      if res and res.lines and #res.lines > 0 then
        -- Add single blank line separator between non-empty sections
        if #all_lines_chunks > 0 then
          table.insert(all_lines_chunks, { { "", nil } })
          current_offset = current_offset + 1
        end

        for _, line_def in ipairs(res.lines) do
          table.insert(all_lines_chunks, normalize_line(line_def))
        end

        for _, hl in ipairs(res.highlights or {}) do
          table.insert(legacy_highlights, {
            line = hl.line + current_offset,
            start_col = hl.start_col,
            end_col = hl.end_col,
            hl = resolve_hl(hl.hl),
          })
        end

        for _, item in ipairs(res.items or {}) do
          table.insert(interactive_items, {
            line = (item.line_idx or item.line) + current_offset,
            key = item.key,
            action = item.action,
            type = item.type,
            label = item.label,
            path = item.path,
          })
        end

        current_offset = current_offset + #res.lines
      end
    end
  end

  -- 2. Calculate display width for centering
  local max_w = 0
  for _, chunks in ipairs(all_lines_chunks) do
    local line_w = 0
    for _, c in ipairs(chunks) do
      line_w = line_w + vim.fn.strdisplaywidth(c[1] or "")
    end
    if line_w > max_w then
      max_w = line_w
    end
  end

  -- 3. Calculate horizontal and vertical padding
  local left_pad = config.align == "left" and (config.margin or 4) or math.max(0, math.floor((win_w - max_w) / 2))
  local win_h = vim.api.nvim_win_get_height(win)
  local top_pad = math.max(0, math.floor((win_h - #all_lines_chunks) / 2))
  if config.padding_top and config.padding_top > 0 then
    top_pad = math.max(config.padding_top, top_pad)
  end

  -- 4. Construct buffer lines and extmarks
  local final_lines = {}
  for _ = 1, top_pad do
    table.insert(final_lines, "")
  end

  local pad_str = string.rep(" ", left_pad)
  local pad_len = #pad_str
  local extmarks = {}

  for i, chunks in ipairs(all_lines_chunks) do
    local buf_line_0 = top_pad + i - 1
    local line_parts = {}
    local col = pad_len

    for _, c in ipairs(chunks) do
      local c_text, c_hl = c[1] or "", c[2]
      table.insert(line_parts, c_text)
      local byte_len = #c_text
      if c_hl and byte_len > 0 then
        table.insert(extmarks, {
          line = buf_line_0,
          col = col,
          end_col = col + byte_len,
          hl = c_hl,
        })
      end
      col = col + byte_len
    end

    local text = table.concat(line_parts)
    table.insert(final_lines, text == "" and "" or (pad_str .. text))
  end

  -- 5. Apply buffer lines atomically
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)
  vim.bo[buf].modifiable = false

  -- 6. Apply extmarks
  local ns = vim.api.nvim_create_namespace("startinator")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for _, em in ipairs(extmarks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, em.line, em.col, {
      end_col = em.end_col,
      hl_group = em.hl,
    })
  end

  for _, hl in ipairs(legacy_highlights) do
    if hl.hl then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, hl.line + top_pad - 1, hl.start_col + pad_len, {
        end_col = hl.end_col + pad_len,
        hl_group = hl.hl,
      })
    end
  end

  -- 7. Map interactive items to 1-indexed buffer lines
  local mapped_items = {}
  local items_by_line = {}
  for _, item in ipairs(interactive_items) do
    local actual_line = item.line + top_pad
    item.buf_line = actual_line
    item.col = left_pad
    table.insert(mapped_items, item)
    items_by_line[actual_line] = item
  end

  vim.b[buf].startinator_items = mapped_items
  vim.b[buf].startinator_line_map = items_by_line

  -- 8. Position cursor on first interactive item
  if #mapped_items > 0 then
    pcall(vim.api.nvim_win_set_cursor, win, { mapped_items[1].buf_line, mapped_items[1].col })
  end
end

return M
