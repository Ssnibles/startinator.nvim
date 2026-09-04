local M = {}

--- Render shortcuts section in modern right-aligned style
--- @param config table
--- @return table
function M.render(config)
  local opts = config.shortcuts
  if not opts or not opts.enabled or not opts.items or #opts.items == 0 then
    return { lines = {}, items = {} }
  end

  local lines = {}
  local items = {}
  local block_width = config._resolved_width or config.width or 46

  -- Section Header Divider: ─ Actions ─────────────────────────
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

  -- Determine if any items have icons
  local has_any_icons = false
  for _, it in ipairs(opts.items) do
    if it.icon and it.icon ~= "" then
      has_any_icons = true
      break
    end
  end

  for _, item in ipairs(opts.items) do
    local icon_str = ""
    if has_any_icons then
      if item.icon and item.icon ~= "" then
        icon_str = item.icon .. "  "
      else
        icon_str = "    "
      end
    end

    local desc_str = item.desc or ""
    local key_str = item.key or ""

    local left_w = vim.fn.strdisplaywidth(icon_str .. desc_str)
    local right_w = vim.fn.strdisplaywidth(key_str)
    local pad_spaces = math.max(2, block_width - left_w - right_w)

    local line_chunks = {
      { icon_str, "StartinatorShortcutIcon" },
      { desc_str, "StartinatorShortcutDesc" },
      { string.rep(" ", pad_spaces), nil },
      { key_str, "StartinatorShortcutKey" },
    }

    table.insert(lines, line_chunks)

    table.insert(items, {
      line_idx = #lines,
      key = item.key,
      action = item.action,
      type = "shortcut",
      label = item.desc,
    })
  end

  return {
    lines = lines,
    items = items,
  }
end

return M
