local actions = require("startinator.actions")

local M = {}

--- Move cursor to next or previous interactive item with smooth wraparound
--- @param buf number
--- @param direction number (1 for next, -1 for prev)
local function move_cursor(buf, direction)
  local items = vim.b[buf].startinator_items or {}
  if #items == 0 then
    return
  end

  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local target_item = nil

  if direction > 0 then
    -- Find next item below current line
    for _, item in ipairs(items) do
      if item.buf_line > cur_line then
        target_item = item
        break
      end
    end
    -- Wrap around to first item
    if not target_item then
      target_item = items[1]
    end
  else
    -- Find previous item above current line
    for i = #items, 1, -1 do
      local item = items[i]
      if item.buf_line < cur_line then
        target_item = item
        break
      end
    end
    -- Wrap around to last item
    if not target_item then
      target_item = items[#items]
    end
  end

  if target_item then
    pcall(vim.api.nvim_win_set_cursor, 0, { target_item.buf_line, target_item.col or 2 })
  end
end

--- Execute the item currently under the cursor
--- @param buf number
local function select_current_item(buf)
  local items_by_line = vim.b[buf].startinator_line_map or {}
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local item = items_by_line[cur_line]
  if item then
    actions.execute(item.action, buf)
  end
end

--- Handle mouse click positioning and activation
--- @param buf number
local function handle_mouse_click(buf)
  local mouse = vim.fn.getmousepos()
  local cur_win = vim.api.nvim_get_current_win()
  if mouse.winid == cur_win then
    local items_by_line = vim.b[buf].startinator_line_map or {}
    local item = items_by_line[mouse.line]
    if item then
      pcall(vim.api.nvim_win_set_cursor, 0, { item.buf_line, item.col or 2 })
      actions.execute(item.action, buf)
    end
  end
end

--- Setup buffer-local keymaps
--- @param buf number
--- @param config table
function M.setup(buf, config)
  local opts = { buffer = buf, silent = true, noremap = true, nowait = true }
  local km = config.keymaps or {}

  -- Helper to normalize keys to a list
  local function to_list(val)
    if type(val) == "string" then
      return { val }
    elseif type(val) == "table" then
      return val
    end
    return {}
  end

  -- 1. Next item navigation
  local next_keys = to_list(km.next or { "j", "<Down>", "<Tab>" })
  for _, k in ipairs(next_keys) do
    vim.keymap.set("n", k, function()
      move_cursor(buf, 1)
    end, opts)
  end

  -- 2. Previous item navigation
  local prev_keys = to_list(km.prev or { "k", "<Up>", "<S-Tab>" })
  for _, k in ipairs(prev_keys) do
    vim.keymap.set("n", k, function()
      move_cursor(buf, -1)
    end, opts)
  end

  -- 3. Select item under cursor
  local select_keys = to_list(km.select or { "<CR>", "<Space>", "l" })
  for _, k in ipairs(select_keys) do
    vim.keymap.set("n", k, function()
      select_current_item(buf)
    end, opts)
  end

  -- 4. Inhibit left cursor wandering
  for _, k in ipairs({ "h", "<Left>" }) do
    vim.keymap.set("n", k, "<Nop>", opts)
  end

  -- 5. Quick new file (starts typing immediately)
  local new_keys = to_list(km.new_file or { "i", "a", "o" })
  for _, k in ipairs(new_keys) do
    vim.keymap.set("n", k, function()
      actions.new_file()
    end, opts)
  end

  -- 6. Quit
  local quit_keys = to_list(km.quit or { "q", "<Esc>" })
  for _, k in ipairs(quit_keys) do
    vim.keymap.set("n", k, function()
      actions.quit(buf)
    end, opts)
  end

  -- 7. Mouse click
  local mouse_key = km.mouse or "<LeftMouse>"
  if mouse_key and mouse_key ~= "" then
    vim.keymap.set("n", mouse_key, function()
      handle_mouse_click(buf)
    end, opts)
  end

  -- 8. Register direct item hotkeys (e.g. 'f', 'r', 'n', '1', '2', etc.)
  local items = vim.b[buf].startinator_items or {}
  local bound_keys = {}

  for _, item in ipairs(items) do
    if item.key and not bound_keys[item.key] then
      bound_keys[item.key] = true
      vim.keymap.set("n", item.key, function()
        actions.execute(item.action, buf)
      end, opts)
    end
  end
end

return M
