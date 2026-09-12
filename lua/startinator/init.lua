local config = require("startinator.config")
local render = require("startinator.render")
local keymaps = require("startinator.keymaps")
local actions = require("startinator.actions")

local M = {}

--- Options to save and restore for the dashboard window
local WIN_OPTS = {
  number = false,
  relativenumber = false,
  signcolumn = "no",
  foldcolumn = "0",
  foldenable = false,
  colorcolumn = "",
  statuscolumn = "",
  wrap = false,
  spell = false,
  list = false,
  cursorline = true,
  cursorcolumn = false,
  fillchars = "eob: ",
}

--- Setup plugin configuration
---@param opts table|nil
function M.setup(opts)
  config.setup(opts)
end

--- Register a custom action
---@param name string
---@param fn function
function M.register_action(name, fn)
  actions.register(name, fn)
end

--- Register a custom section renderer
---@param name string
---@param renderer table|function
function M.register_section(name, renderer)
  render.register_section(name, renderer)
end

--- Open startpage in the current or a new buffer
function M.open()
  local current_buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  -- Check if we can reuse the current empty, unmodified buffer
  local is_empty = false
  if vim.api.nvim_buf_get_name(current_buf) == "" and vim.bo[current_buf].buftype == "" and not vim.bo[current_buf].modified then
    local lines = vim.api.nvim_buf_get_lines(current_buf, 0, 2, false)
    if #lines <= 1 and (lines[1] == "" or lines[1] == nil) then
      is_empty = true
    end
  end

  local buf
  if vim.bo[current_buf].filetype == "startinator" or is_empty then
    buf = current_buf
  else
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
  end

  -- Save existing window options to restore when leaving dashboard
  local saved_win_opts = {}
  for opt in pairs(WIN_OPTS) do
    saved_win_opts[opt] = vim.api.nvim_get_option_value(opt, { win = win })
  end

  -- Set buffer options
  local buf_opts = {
    filetype = "startinator",
    buftype = "nofile",
    bufhidden = "wipe",
    swapfile = false,
    buflisted = false,
    modifiable = false,
    undolevels = -1,
  }
  for opt, val in pairs(buf_opts) do
    vim.bo[buf][opt] = val
  end

  -- Apply distraction-free window options
  for opt, val in pairs(WIN_OPTS) do
    pcall(vim.api.nvim_set_option_value, opt, val, { win = win })
  end

  -- Render sections and attach keymaps
  render.draw(buf, win, config.options)
  keymaps.setup(buf, config.options)

  -- Augroup for buffer events
  local group_name = "StartinatorBuffer_" .. buf
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  -- Redraw on terminal resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win) then
        render.draw(buf, win, config.options)
      end
    end,
  })

  local restored = false
  local function restore_win_opts()
    if restored then
      return
    end
    restored = true
    if vim.api.nvim_win_is_valid(win) then
      for opt, val in pairs(saved_win_opts) do
        pcall(vim.api.nvim_set_option_value, opt, val, { win = win })
      end
    end
    pcall(vim.api.nvim_del_augroup_by_name, group_name)
  end

  -- Restore original window options when navigating away or buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = restore_win_opts,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) ~= buf then
        restore_win_opts()
      end
    end,
  })
end

--- Close startpage if currently open
function M.close()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.bo[current_buf].filetype == "startinator" then
    actions.quit(current_buf)
  end
end

--- Toggle startpage open / close
function M.toggle()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.bo[current_buf].filetype == "startinator" then
    M.close()
  else
    M.open()
  end
end

return M
