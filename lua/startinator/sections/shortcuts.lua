local utils = require("startinator.utils")

local M = {}

--- Render shortcuts section
---@param config table
---@return table
function M.render(config)
  local opts = config.shortcuts
  if not opts or not opts.enabled or not opts.items or #opts.items == 0 then
    return { lines = {}, items = {} }
  end

  local lines = {}
  local items = {}
  local width = config._resolved_width or config.width or 46

  -- Section divider
  if opts.title and opts.title ~= "" then
    table.insert(lines, utils.divider(opts.title, width))
  end

  -- Align indentation if any item has an icon
  local has_icons = false
  for _, it in ipairs(opts.items) do
    if it.icon and it.icon ~= "" then
      has_icons = true
      break
    end
  end

  for _, item in ipairs(opts.items) do
    local icon_str = ""
    if has_icons then
      icon_str = (item.icon and item.icon ~= "") and (item.icon .. "  ") or "    "
    end

    local left = {
      { icon_str, "StartinatorShortcutIcon" },
      { item.desc or "", "StartinatorShortcutDesc" },
    }
    local right = {
      { item.key or "", "StartinatorShortcutKey" },
    }

    table.insert(lines, utils.align_row(left, right, width))
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
