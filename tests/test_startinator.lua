-- Minimal headless test suite for startinator.nvim.
--
-- Run with:
--   nvim --headless -u NONE -l tests/test_startinator.lua

local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(root)

local failures = {}
local passed = 0

local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    table.insert(failures, msg)
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

local function pcall_check(name, fn)
  local ok, err = pcall(fn)
  check(ok, name .. (ok and "" or (": " .. tostring(err))))
end

local function fresh_open(opts)
  vim.cmd("enew!")
  local s = require("startinator")
  local merged = vim.tbl_extend("force", { auto_open = false }, opts or {})
  s.setup(merged)
  s.open()
  return vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
end

-- 1. The dashboard renders and registers interactive items.
do
  local buf = fresh_open()
  check(vim.bo[buf].filetype == "startinator", "dashboard sets filetype")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  check(#lines > 0, "dashboard renders lines")
  check(type(vim.b[buf].startinator_items) == "table" and #vim.b[buf].startinator_items > 0, "dashboard registers items")
end

-- 2. Regression: the line map must not contain userdata sentinels, and
--    update_active must be safe on every line (including blank ones).
do
  local buf = fresh_open()
  local win = vim.api.nvim_get_current_win()
  local map = vim.b[buf].startinator_line_map
  check(type(map) == "table", "line map is a table")

  local bad = false
  for k, v in pairs(map) do
    if type(k) ~= "string" or type(v) ~= "table" then
      bad = true
    end
  end
  check(not bad, "line map stores string keys with table values (no userdata sentinels)")

  local cfg = require("startinator.config").options
  local render = require("startinator.render")
  for l = 1, vim.api.nvim_buf_line_count(buf) do
    pcall_check("update_active on line " .. l, function()
      vim.api.nvim_win_set_cursor(win, { l, 0 })
      render.update_active(buf, win, cfg)
    end)
  end
end

-- 3. Regression: pressing the select key on a non-item line must not error.
do
  local buf = fresh_open()
  local win = vim.api.nvim_get_current_win()
  local function find_cb(lhs)
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      if m.lhs == lhs and type(m.callback) == "function" then
        return m.callback
      end
    end
  end
  local select_cb = find_cb("<CR>")
  check(select_cb ~= nil, "<CR> keymap is registered")
  vim.api.nvim_win_set_cursor(win, { 1, 0 }) -- padding line, not an item
  pcall_check("select on blank line is safe", function()
    select_cb()
  end)
end

-- 4. close() works even when the dashboard is not the current buffer.
do
  local buf = fresh_open()
  vim.cmd("enew!")
  check(vim.api.nvim_get_current_buf() ~= buf, "switched to another buffer")
  require("startinator").close()
  check(not vim.api.nvim_buf_is_valid(buf), "close() wipes the dashboard from another buffer")
end

-- 5. List options override (rather than merge with) the defaults.
do
  require("startinator").setup({ auto_open = false, sections = { "footer" } })
  local config = require("startinator.config")
  check(vim.deep_equal(config.options.sections, { "footer" }), "sections override replaces defaults")
end

-- 6. MRU renders an oldfile that lives under the cwd.
do
  vim.cmd("enew!")
  vim.api.nvim_set_current_dir(root)
  vim.v.oldfiles = { root .. "/README.md" }
  require("startinator").setup({ auto_open = false, mru = { limit = 5, cwd_only = true } })
  require("startinator").open()
  local buf = vim.api.nvim_get_current_buf()
  local found = false
  for _, it in ipairs(vim.b[buf].startinator_items or {}) do
    if it.type == "mru" then
      found = true
    end
  end
  check(found, "MRU renders an entry for an oldfile under cwd")
end

-- 7. Window options are restored after leaving the dashboard.
do
  vim.cmd("enew!")
  vim.wo.number = true
  vim.wo.signcolumn = "yes"
  require("startinator").setup({ auto_open = false })
  require("startinator").open()
  check(vim.wo.number == false, "dashboard disables number")
  vim.cmd("edit " .. vim.fn.fnameescape(root .. "/README.md"))
  check(vim.wo.number == true, "number restored after leaving dashboard")
  check(vim.wo.signcolumn == "yes", "signcolumn restored after leaving dashboard")
end

-- 8. Rendering must not mutate the shared options table.
do
  local config = require("startinator.config")
  fresh_open()
  check(config.options._resolved_width == nil, "draw does not mutate shared config")
end

-- 9. Hotkeys are rebound (and stale ones removed) on re-render.
do
  local buf = fresh_open()
  local function has(lhs)
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      if m.lhs == lhs then
        return true
      end
    end
    return false
  end
  check(has("f"), "shortcut hotkey `f` is bound")
  vim.b[buf].startinator_items = { { key = "z", action = function() end } }
  require("startinator.keymaps").setup(buf, require("startinator.config").options)
  check(has("z"), "new hotkey `z` is bound after re-render")
  check(not has("f"), "stale hotkey `f` is unbound after re-render")
end

-- 10. close() closes every open dashboard, not just the most recent.
do
  local s = require("startinator")
  vim.cmd("edit " .. vim.fn.fnameescape(root .. "/README.md"))
  s.setup({ auto_open = false })
  vim.cmd("vsplit")
  vim.cmd("enew!")
  s.open()
  local a = vim.api.nvim_get_current_buf()
  vim.cmd("wincmd p")
  vim.cmd("enew!")
  s.open()
  local b = vim.api.nvim_get_current_buf()
  check(a ~= b and vim.bo[a].filetype == "startinator" and vim.bo[b].filetype == "startinator", "two dashboards are open")
  s.close()
  check(not vim.api.nvim_buf_is_valid(a), "close() closed the first dashboard")
  check(not vim.api.nvim_buf_is_valid(b), "close() closed the second dashboard")
end

-- 11. :checkhealth entry point runs.
do
  local health = require("startinator.health")
  local started = nil
  local orig = vim.health
  vim.health = {
    start = function(name)
      started = name
    end,
    ok = function() end,
    warn = function() end,
    error = function() end,
    info = function() end,
  }
  local ok, err = pcall(health.check)
  vim.health = orig
  check(ok and started == "startinator.nvim", "health check runs" .. (ok and "" or (": " .. tostring(err))))
end

-- 12. Opening in a very narrow window does not error.
do
  vim.cmd("enew!")
  vim.cmd("vsplit")
  vim.cmd("vertical resize 10")
  local s = require("startinator")
  s.setup({ auto_open = false })
  local ok, err = pcall(s.open)
  check(ok, "open in a narrow window does not error" .. (ok and "" or (": " .. tostring(err))))
end

-- 13. Long cwd paths are left-truncated at whole path segments to fit the
--     same content width as the sections below the header.
do
  local utils = require("startinator.utils")
  local truncated = utils.truncate_path_left("/home/josh/dev/my-project", 20)
  check(truncated == ".../dev/my-project", "truncate_path_left keeps whole trailing segments")
  check(vim.fn.strdisplaywidth(truncated) <= 20, "truncate_path_left respects the width bound")

  local hard = utils.truncate_path_left("~/verylongsingleworddirectoryname", 12)
  check(vim.fn.strdisplaywidth(hard) <= 12, "truncate_path_left respects width without segment boundaries")

  local deep = "/tmp/" .. string.rep("segment/", 8) .. "final"
  vim.fn.mkdir(deep, "p")
  local original_cwd = vim.fn.getcwd()
  vim.api.nvim_set_current_dir(deep)
  local header = require("startinator.sections.header")
  local res = header.render({ header = { enabled = true, cwd = true }, _resolved_width = 30 })
  vim.api.nvim_set_current_dir(original_cwd)
  local cwd_line = nil
  for _, line in ipairs(res.lines) do
    for _, chunk in ipairs(line) do
      if chunk[2] == "StartinatorCwd" then
        cwd_line = chunk[1]
      end
    end
  end
  check(cwd_line ~= nil, "header renders a cwd line")
  check(vim.fn.strdisplaywidth(cwd_line) <= 30, "header cwd fits the shared content width")
  check(cwd_line:find("%.%.%.") ~= nil, "header cwd is marked with an ellipsis when trimmed")
end

io.stdout:write(string.format("\n%d checks passed, %d failed\n", passed, #failures))
io.stdout:flush()
if #failures > 0 then
  os.exit(1)
end
