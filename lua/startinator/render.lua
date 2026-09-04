local utils = require("startinator.utils")

local M = {}

--- Resolve highlight group name safely
--- @param hl string|nil
--- @return string|nil
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
--- @param line_def any
--- @return table
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

  if #chunks == 0 then
    table.insert(chunks, { "", nil })
  end

  return chunks
end

--- Render all configured sections and draw to dashboard buffer
--- @param buf number
--- @param win number
--- @param config table
function M.draw(buf, win, config)
  utils.setup_highlights(config.highlights or {})

  local win_width = vim.api.nvim_win_get_width(win)
  local target_w = config.width or 46
  local block_width = math.min(target_w, math.max(20, win_width - 4))
  config._resolved_width = block_width

  local all_lines_chunks = {}
  local legacy_highlights = {}
  local interactive_items = {}
  local current_line_offset = 0

  -- 1. Gather all section outputs
  for _, sec in ipairs(config.sections or {}) do
    local sec_module = nil
    if type(sec) == "string" then
      local ok, mod = pcall(require, "startinator.sections." .. sec)
      if ok then
        sec_module = mod
      end
    elseif type(sec) == "table" and sec.render then
      sec_module = sec
    elseif type(sec) == "function" then
      sec_module = { render = sec }
    end

    if sec_module then
      local res = sec_module.render(config)
      if res and res.lines and #res.lines > 0 then
        -- Add 1 empty line separator between non-empty sections
        if #all_lines_chunks > 0 then
          table.insert(all_lines_chunks, { { "", nil } })
          current_line_offset = current_line_offset + 1
        end

        for _, line_def in ipairs(res.lines) do
          local chunks = normalize_line(line_def)
          table.insert(all_lines_chunks, chunks)
        end

        -- Collect legacy highlights if provided
        for _, hl in ipairs(res.highlights or {}) do
          table.insert(legacy_highlights, {
            line = hl.line + current_line_offset,
            start_col = hl.start_col,
            end_col = hl.end_col,
            hl = resolve_hl(hl.hl),
          })
        end

        -- Map interactive items to cumulative line index
        for _, item in ipairs(res.items or {}) do
          table.insert(interactive_items, {
            line = (item.line_idx or item.line) + current_line_offset,
            key = item.key,
            action = item.action,
            type = item.type,
            label = item.label,
            path = item.path,
          })
        end

        current_line_offset = current_line_offset + #res.lines
      end
    end
  end

  -- 2. Calculate display widths for block centering
  local max_w = 0
  local line_texts = {}
  for i, chunks in ipairs(all_lines_chunks) do
    local parts = {}
    for _, c in ipairs(chunks) do
      table.insert(parts, c[1])
    end
    local text = table.concat(parts)
    line_texts[i] = text
    local w = vim.fn.strdisplaywidth(text)
    if w > max_w then
      max_w = w
    end
  end

  -- 3. Calculate horizontal padding
  local left_pad = 0
  if config.align == "center" then
    left_pad = math.max(0, math.floor((win_width - max_w) / 2))
  else
    left_pad = config.margin or 4
  end

  -- 4. Calculate vertical top padding (true vertical centering)
  local win_height = vim.api.nvim_win_get_height(win)
  local rem = win_height - #all_lines_chunks
  local top_pad = 0
  if rem > 0 then
    top_pad = math.floor(rem / 2)
  end
  if config.padding_top and config.padding_top > 0 then
    top_pad = math.max(config.padding_top, top_pad)
  end

  -- 5. Construct final buffer lines and calculate exact byte-offset highlights
  local final_lines = {}
  for _ = 1, top_pad do
    table.insert(final_lines, "")
  end

  local pad_str = string.rep(" ", left_pad)
  local pad_len = #pad_str
  local extmarks = {}

  for i, chunks in ipairs(all_lines_chunks) do
    local text = line_texts[i]
    local buf_line_0 = top_pad + i - 1 -- 0-indexed line in buffer

    if text == "" then
      table.insert(final_lines, "")
    else
      table.insert(final_lines, pad_str .. text)

      local col = pad_len
      for _, c in ipairs(chunks) do
        local c_text, c_hl = c[1], c[2]
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
    end
  end

  -- 6. Apply lines atomically
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)
  vim.bo[buf].modifiable = false

  -- 7. Apply extmarks & legacy highlights
  local ns_id = vim.api.nvim_create_namespace("startinator")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  for _, em in ipairs(extmarks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, em.line, em.col, {
      end_col = em.end_col,
      hl_group = em.hl,
    })
  end

  for _, hl in ipairs(legacy_highlights) do
    local buf_line_0 = hl.line + top_pad - 1
    local s_col = hl.start_col + pad_len
    local e_col = hl.end_col + pad_len
    if hl.hl then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, buf_line_0, s_col, {
        end_col = e_col,
        hl_group = hl.hl,
      })
    end
  end

  -- 8. Map interactive items to final 1-indexed buffer lines
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

  -- 9. Move cursor to first interactive item
  if #mapped_items > 0 then
    pcall(vim.api.nvim_win_set_cursor, win, { mapped_items[1].buf_line, mapped_items[1].col })
  end
end

return M
