local actions = require("startinator.actions")
local render = require("startinator.render")

local M = {}

--- Move cursor to next or previous interactive item with wrap-around
---@param buf number
---@param dir number (1 for next, -1 for prev)
---@param config table
local function move_cursor(buf, dir, config)
  local items = vim.b[buf].startinator_items or {}
  if #items == 0 then
    return
  end

  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local target = nil

  if dir > 0 then
    for _, item in ipairs(items) do
      if item.buf_line > cur_line then
        target = item
        break
      end
    end
    target = target or items[1]
  else
    for i = #items, 1, -1 do
      if items[i].buf_line < cur_line then
        target = items[i]
        break
      end
    end
    target = target or items[#items]
  end

  if target then
    pcall(vim.api.nvim_win_set_cursor, 0, { target.buf_line, target.col or 2 })
    render.update_active(buf, 0, config)
  end
end

--- Execute the item currently under the cursor
---@param buf number
local function select_current_item(buf)
  local map = vim.b[buf].startinator_line_map or {}
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local item = map[cur_line]
  if item then
    actions.execute(item.action, buf)
  end
end

--- Handle mouse click positioning and activation
---@param buf number
---@param config table
local function handle_mouse_click(buf, config)
  local mouse = vim.fn.getmousepos()
  if mouse.winid == vim.api.nvim_get_current_win() then
    local map = vim.b[buf].startinator_line_map or {}
    local item = map[mouse.line]
    if item then
      pcall(vim.api.nvim_win_set_cursor, 0, { item.buf_line, item.col or 2 })
      render.update_active(buf, 0, config)
      actions.execute(item.action, buf)
    end
  end
end

--- Setup buffer-local keymaps
---@param buf number
---@param config table
function M.setup(buf, config)
  local opts = { buffer = buf, silent = true, noremap = true, nowait = true }
  local km = config.keymaps or {}

  local function to_list(val)
    if type(val) == "string" then
      return { val }
    end
    return type(val) == "table" and val or {}
  end

  local mappings = {
    { keys = km.next or { "j", "<Down>", "<Tab>" }, fn = function() move_cursor(buf, 1, config) end },
    { keys = km.prev or { "k", "<Up>", "<S-Tab>" }, fn = function() move_cursor(buf, -1, config) end },
    { keys = km.select or { "<CR>", "<Space>", "l" }, fn = function() select_current_item(buf) end },
    { keys = { "h", "<Left>" }, fn = "<Nop>" },
    { keys = km.oil or km.explorer or { "e" }, fn = actions.oil },
    { keys = km.new_file or { "i", "a", "o" }, fn = actions.new_file },
    { keys = km.quit or { "q", "<Esc>" }, fn = function() actions.quit(buf) end },
  }

  for _, m in ipairs(mappings) do
    for _, k in ipairs(to_list(m.keys)) do
      vim.keymap.set("n", k, m.fn, opts)
    end
  end

  local mouse_key = km.mouse or "<LeftMouse>"
  if mouse_key and mouse_key ~= "" then
    vim.keymap.set("n", mouse_key, function()
      handle_mouse_click(buf, config)
    end, opts)
  end

  -- Register direct item hotkeys (e.g. 'f', 'e', 'n', '1'..'9')
  local items = vim.b[buf].startinator_items or {}
  local bound = {}

  for _, item in ipairs(items) do
    if item.key and not bound[item.key] then
      bound[item.key] = true
      vim.keymap.set("n", item.key, function()
        actions.execute(item.action, buf)
      end, opts)
    end
  end
end

return M
