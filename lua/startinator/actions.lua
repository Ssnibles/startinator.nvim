local M = {}

--- Safe call helper that notifies user on error instead of throwing a traceback
--- @param fn function
--- @return boolean success, any result
local function safe_call(fn)
  local ok, res = pcall(fn)
  if not ok then
    vim.notify("startinator: " .. tostring(res), vim.log.levels.WARN)
  end
  return ok, res
end

--- Find files using the best available picker or native fallback
function M.find_files()
  -- 1. Snacks.picker
  if pcall(require, "snacks") and _G.Snacks and _G.Snacks.picker then
    return safe_call(function() _G.Snacks.picker.files() end)
  end

  -- 2. fzf-lua
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if ok_fzf then
    return safe_call(function() fzf.files() end)
  end

  -- 3. Telescope
  local ok_tele, builtin = pcall(require, "telescope.builtin")
  if ok_tele then
    return safe_call(function() builtin.find_files() end)
  end

  -- 4. mini.pick
  local ok_mini, mini_pick = pcall(require, "mini.pick")
  if ok_mini and mini_pick.builtin and mini_pick.builtin.files then
    return safe_call(function() mini_pick.builtin.files() end)
  end

  -- 5. Native fallback: open file explorer / netrw
  safe_call(function() vim.cmd("edit .") end)
end

--- Find recent files using the best available picker or native fallback
function M.recent_files()
  -- 1. Snacks.picker
  if pcall(require, "snacks") and _G.Snacks and _G.Snacks.picker then
    return safe_call(function() _G.Snacks.picker.recent() end)
  end

  -- 2. fzf-lua
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if ok_fzf then
    return safe_call(function() fzf.oldfiles() end)
  end

  -- 3. Telescope
  local ok_tele, builtin = pcall(require, "telescope.builtin")
  if ok_tele then
    return safe_call(function() builtin.oldfiles() end)
  end

  -- 4. mini.pick
  local ok_mini, mini_pick = pcall(require, "mini.pick")
  if ok_mini and mini_pick.builtin and mini_pick.builtin.cli then
    return safe_call(function()
      mini_pick.builtin.cli({ command = { "git", "status" } })
    end)
  end

  -- 5. Native fallback: browse oldfiles
  safe_call(function() vim.cmd("browse oldfiles") end)
end

--- Live grep using the best available picker or native fallback
function M.live_grep()
  -- 1. Snacks.picker
  if pcall(require, "snacks") and _G.Snacks and _G.Snacks.picker then
    return safe_call(function() _G.Snacks.picker.grep() end)
  end

  -- 2. fzf-lua
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if ok_fzf then
    return safe_call(function() fzf.live_grep() end)
  end

  -- 3. Telescope
  local ok_tele, builtin = pcall(require, "telescope.builtin")
  if ok_tele then
    return safe_call(function() builtin.live_grep() end)
  end

  -- 4. mini.pick
  local ok_mini, mini_pick = pcall(require, "mini.pick")
  if ok_mini and mini_pick.builtin and mini_pick.builtin.grep_live then
    return safe_call(function() mini_pick.builtin.grep_live() end)
  end

  -- 5. Native fallback: vimgrep prompt
  local pattern = vim.fn.input("Live Grep > ")
  if pattern and pattern ~= "" then
    safe_call(function()
      vim.cmd("silent grep! " .. vim.fn.fnameescape(pattern) .. " | copen")
    end)
  end
end

--- Create and edit a new unnamed buffer, entering insert mode immediately
function M.new_file()
  vim.cmd("enew")
  vim.cmd("startinsert")
end

--- Open Neovim configuration file
function M.config()
  local config_file = vim.fn.stdpath("config") .. "/init.lua"
  if vim.uv.fs_stat(config_file) then
    vim.cmd("edit " .. vim.fn.fnameescape(config_file))
  else
    vim.cmd("edit $MYVIMRC")
  end
end

--- Smart quit: if startinator is the only buffer, exit Neovim; otherwise close startinator
--- @param buf number|nil
function M.quit(buf)
  local valid_buffers = 0
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and b ~= buf then
      valid_buffers = valid_buffers + 1
    end
  end

  if valid_buffers > 0 then
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    else
      vim.cmd("silent! bdelete!")
    end
  else
    vim.cmd("quitall")
  end
end

--- Execute an action (named string, Vim command string, or Lua function)
--- @param act string|function
--- @param buf number|nil
function M.execute(act, buf)
  if not act then
    return
  end

  if type(act) == "function" then
    safe_call(act)
    return
  end

  if type(act) == "string" then
    if act == "find_files" then
      M.find_files()
    elseif act == "recent_files" then
      M.recent_files()
    elseif act == "live_grep" then
      M.live_grep()
    elseif act == "new_file" then
      M.new_file()
    elseif act == "config" then
      M.config()
    elseif act == "quit" then
      M.quit(buf)
    else
      safe_call(function() vim.cmd(act) end)
    end
  end
end

return M
