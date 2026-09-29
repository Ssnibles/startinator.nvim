local M = {}

local uv = vim.uv or vim.loop

--- Safe call helper that notifies user on error instead of throwing a traceback
---@param fn function
---@return boolean success, any result
local function safe_call(fn)
  local ok, res = pcall(fn)
  if not ok then
    vim.notify("startinator: " .. tostring(res), vim.log.levels.WARN)
  end
  return ok, res
end

--- Supported fuzzy pickers in priority order
local pickers = {
  {
    name = "snacks",
    available = function()
      return pcall(require, "snacks") and _G.Snacks and _G.Snacks.picker
    end,
    files = function()
      _G.Snacks.picker.files()
    end,
    recent = function(cwd_only)
      _G.Snacks.picker.recent(cwd_only and { filter = { cwd = true } } or nil)
    end,
    grep = function()
      _G.Snacks.picker.grep()
    end,
  },
  {
    name = "fzf-lua",
    available = function()
      local ok, f = pcall(require, "fzf-lua")
      return ok and f
    end,
    files = function(f)
      f.files()
    end,
    recent = function(f, cwd_only)
      f.oldfiles({ cwd_only = cwd_only })
    end,
    grep = function(f)
      f.live_grep()
    end,
  },
  {
    name = "telescope",
    available = function()
      local ok, t = pcall(require, "telescope.builtin")
      return ok and t
    end,
    files = function(t)
      t.find_files()
    end,
    recent = function(t, cwd_only)
      t.oldfiles({ cwd_only = cwd_only })
    end,
    grep = function(t)
      t.live_grep()
    end,
  },
  {
    name = "mini.pick",
    available = function()
      local ok, m = pcall(require, "mini.pick")
      return ok and m.builtin and m
    end,
    files = function(m)
      m.builtin.files()
    end,
    recent = function(m, cwd_only)
      -- mini.pick has no oldfiles builtin; build a source from v:oldfiles.
      if not m.start then
        return false
      end
      local cwd = vim.fn.getcwd()
      local items = {}
      for _, path in ipairs(vim.v.oldfiles or {}) do
        if type(path) == "string" and path ~= "" then
          local abs = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
          if vim.fn.filereadable(abs) == 1 and (not cwd_only or vim.fs.relpath(cwd, abs) ~= nil) then
            table.insert(items, abs)
          end
        end
      end
      if #items == 0 then
        return false
      end
      m.start({
        source = {
          name = "Recent files",
          items = items,
          choose = function(item)
            vim.cmd("edit " .. vim.fn.fnameescape(item))
          end,
        },
      })
      return true
    end,
    grep = function(m)
      m.builtin.grep_live()
    end,
  },
}

--- Run a picker method if an integrated picker is found, otherwise run fallback
---@param method string "files"|"recent"|"grep"
---@param arg any
---@param fallback function
local function run_picker(method, arg, fallback)
  for _, p in ipairs(pickers) do
    local handle = p.available()
    if handle and p[method] then
      -- A picker may decline to handle the request by returning `false`, in
      -- which case we keep looking (or fall back).
      local ok, handled = safe_call(function()
        return p[method](handle, arg)
      end)
      if ok and handled ~= false then
        return
      end
    end
  end
  safe_call(fallback)
end

--- Find files using the best available picker or netrw fallback
function M.find_files()
  run_picker("files", nil, function()
    vim.cmd("edit .")
  end)
end

--- Find recent files using the best available picker or browse oldfiles fallback
function M.recent_files()
  local config = require("startinator.config")
  local cwd_only = config.options and config.options.mru and config.options.mru.cwd_only ~= false
  run_picker("recent", cwd_only, function()
    vim.cmd("browse oldfiles")
  end)
end

--- Live grep using the best available picker or vimgrep fallback
function M.live_grep()
  run_picker("grep", nil, function()
    local pattern = vim.fn.input("Live Grep > ")
    if pattern and pattern ~= "" then
      vim.cmd("silent grep! " .. vim.fn.fnameescape(pattern) .. " | copen")
    end
  end)
end

--- Create and edit a new unnamed buffer, entering insert mode immediately
function M.new_file()
  vim.cmd("enew")
  vim.cmd("startinsert")
end

--- Open Neovim configuration file
function M.config()
  local file = vim.fn.stdpath("config") .. "/init.lua"
  local target = (uv.fs_stat(file) and file) or vim.fn.expand("$MYVIMRC")
  vim.cmd("edit " .. vim.fn.fnameescape(target))
end

--- Open file explorer using oil.nvim or warning fallback
function M.oil()
  local ok, oil = pcall(require, "oil")
  if ok then
    local fn = oil.toggle_float or oil.open_float or oil.open
    if fn then
      return safe_call(fn)
    end
  end
  if vim.fn.exists(":Oil") == 2 then
    return safe_call(function()
      vim.cmd("Oil --float")
    end)
  end
  vim.notify("startinator: oil.nvim is not available", vim.log.levels.WARN)
end

--- Smart quit: exit Neovim if startinator is the only buffer, otherwise close dashboard buffer
---@param buf number|nil
function M.quit(buf)
  local valid_buffers = 0
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and b ~= buf then
      valid_buffers = valid_buffers + 1
    end
  end

  if valid_buffers > 0 then
    if buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    else
      vim.cmd("silent! bdelete!")
    end
  else
    vim.cmd("quitall")
  end
end

--- Action registry mapping action names to handlers
M.registry = {
  find_files = M.find_files,
  recent_files = M.recent_files,
  live_grep = M.live_grep,
  new_file = M.new_file,
  config = M.config,
  oil = M.oil,
  explorer = M.oil,
  quit = M.quit,
}

--- Register a custom action by name
---@param name string
---@param fn function
function M.register(name, fn)
  M.registry[name] = fn
end

--- Execute an action (function, registered string name, or Vim Ex command)
---@param act string|function
---@param buf number|nil
function M.execute(act, buf)
  if not act then
    return
  end
  if type(act) == "function" then
    return safe_call(act)
  end
  if type(act) == "string" then
    local handler = M.registry[act]
    if handler then
      return safe_call(function()
        handler(buf)
      end)
    end
    -- Fallback: execute as a Vim command. This is an intentional/documented
    -- feature (e.g. `action = "edit ~/.config/nvim"`); invalid commands are
    -- reported by safe_call rather than silently ignored.
    safe_call(function()
      vim.cmd(act)
    end)
  end
end

return M
