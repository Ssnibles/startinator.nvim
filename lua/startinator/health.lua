local M = {}

--- Detect which integrated pickers are available.
---@return string[]
local function available_pickers()
  local found = {}
  if pcall(require, "snacks") and _G.Snacks and _G.Snacks.picker then
    table.insert(found, "snacks.picker")
  end
  if pcall(require, "fzf-lua") then
    table.insert(found, "fzf-lua")
  end
  if pcall(require, "telescope.builtin") then
    table.insert(found, "telescope")
  end
  if pcall(require, "mini.pick") then
    table.insert(found, "mini.pick")
  end
  return found
end

--- `:checkhealth startinator` entry point.
function M.check()
  local health = vim.health or require("health")
  health.start("startinator.nvim")

  -- Neovim version
  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim >= 0.10")
  else
    health.warn("Neovim >= 0.10 is recommended", { "Some extmark and vim.fs APIs may be unavailable on older versions." })
  end

  -- Configuration sanity
  local config = require("startinator.config")
  local opts = config.options or {}

  if type(opts.width) == "number" and opts.width > 0 then
    health.ok("width = " .. opts.width)
  else
    health.error("`width` must be a positive number", { "Set `width` in your startinator setup." })
  end

  if opts.align == "center" or opts.align == "left" then
    health.ok("align = " .. opts.align)
  else
    health.error("`align` must be 'center' or 'left'")
  end

  if type(opts.sections) == "table" and #opts.sections > 0 then
    health.ok("sections = " .. table.concat(opts.sections, ", "))
  else
    health.warn("No sections configured", { "Add section names to `sections` (e.g. 'header', 'shortcuts', 'mru', 'footer')." })
  end

  -- Pickers
  local pickers = available_pickers()
  if #pickers > 0 then
    health.ok("Fuzzy pickers available: " .. table.concat(pickers, ", "))
  else
    health.warn(
      "No fuzzy picker found",
      { "Install snacks.nvim, fzf-lua, telescope.nvim or mini.pick, or the built-in fallbacks will be used." }
    )
  end

  -- Companion plugins
  if pcall(require, "oil") or vim.fn.exists(":Oil") == 2 then
    health.ok("oil.nvim is available")
  else
    health.info("oil.nvim is not installed (the file explorer shortcut will notify instead)")
  end
end

return M
