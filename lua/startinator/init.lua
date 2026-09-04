local config = require("startinator.config")
local render = require("startinator.render")
local keymaps = require("startinator.keymaps")
local actions = require("startinator.actions")

local M = {}

--- Setup plugin configuration
--- @param opts table|nil
function M.setup(opts)
  config.setup(opts)
end

--- Open startinator startpage in current or new window/buffer
function M.open()
  local current_buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  -- Check if we can reuse the current empty, unmodified buffer
  local buf
  local name = vim.api.nvim_buf_get_name(current_buf)
  local is_empty = false

  if name == "" and vim.bo[current_buf].buftype == "" and not vim.bo[current_buf].modified then
    local lines = vim.api.nvim_buf_get_lines(current_buf, 0, 2, false)
    if #lines <= 1 and (lines[1] == "" or lines[1] == nil) then
      is_empty = true
    end
  end

  if vim.bo[current_buf].filetype == "startinator" then
    buf = current_buf
  elseif is_empty then
    buf = current_buf
  else
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
  end

  -- Save existing window options to restore when leaving dashboard
  local saved_win_opts = {
    number = vim.api.nvim_get_option_value("number", { win = win }),
    relativenumber = vim.api.nvim_get_option_value("relativenumber", { win = win }),
    signcolumn = vim.api.nvim_get_option_value("signcolumn", { win = win }),
    foldcolumn = vim.api.nvim_get_option_value("foldcolumn", { win = win }),
    foldenable = vim.api.nvim_get_option_value("foldenable", { win = win }),
    colorcolumn = vim.api.nvim_get_option_value("colorcolumn", { win = win }),
    statuscolumn = vim.api.nvim_get_option_value("statuscolumn", { win = win }),
    wrap = vim.api.nvim_get_option_value("wrap", { win = win }),
    spell = vim.api.nvim_get_option_value("spell", { win = win }),
    list = vim.api.nvim_get_option_value("list", { win = win }),
    cursorline = vim.api.nvim_get_option_value("cursorline", { win = win }),
    cursorcolumn = vim.api.nvim_get_option_value("cursorcolumn", { win = win }),
    fillchars = vim.api.nvim_get_option_value("fillchars", { win = win }),
  }

  -- Set buffer options
  vim.bo[buf].filetype = "startinator"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].undolevels = -1

  -- Clean, distraction-free window options
  local target_win_opts = {
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
  for opt, val in pairs(target_win_opts) do
    pcall(vim.api.nvim_set_option_value, opt, val, { win = win })
  end

  -- Render sections and attach keymaps
  render.draw(buf, win, config.options)
  keymaps.setup(buf, config.options)

  -- Augroup for buffer events
  local group_name = "StartinatorBuffer_" .. buf
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  -- Redraw cleanly on terminal resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win) then
        render.draw(buf, win, config.options)
      end
    end,
  })

  -- Restore original window options when navigating away to a file
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        for opt, val in pairs(saved_win_opts) do
          pcall(vim.api.nvim_set_option_value, opt, val, { win = win })
        end
      end
      pcall(vim.api.nvim_del_augroup_by_name, group_name)
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
