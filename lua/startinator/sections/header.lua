local utils = require("startinator.utils")

local M = {}

--- Render modern header section
--- @param config table
--- @return table
function M.render(config)
  local opts = config.header
  if not opts or not opts.enabled then
    return { lines = {}, items = {} }
  end

  local lines = {}
  local block_width = config._resolved_width or config.width or 46

  -- 1. ASCII Art (if explicitly provided)
  if opts.art and #opts.art > 0 then
    for _, art_line in ipairs(opts.art) do
      table.insert(lines, { { art_line, "StartinatorHeader" } })
    end
  elseif opts.title and opts.title ~= "" then
    -- 2. Modern Title / Wordmark
    local title_str = tostring(opts.title)
    if (opts.show_icons == false or config.show_icons == false) and title_str:find("") then
      title_str = title_str:gsub("%s*", "")
    end
    if type(opts.title) == "table" then
      for _, t_line in ipairs(opts.title) do
        table.insert(lines, { { t_line, "StartinatorHeader" } })
      end
    else
      table.insert(lines, { { title_str, "StartinatorHeader" } })
    end
  end

  -- 3. Current Working Directory (subtle project context)
  if opts.cwd then
    local cwd = vim.fn.getcwd()
    local home = os.getenv("HOME")
    if home and cwd:sub(1, #home) == home then
      cwd = "~" .. cwd:sub(#home + 1)
    end
    local icon_prefix = (opts.show_icons ~= false and config.show_icons ~= false) and "  " or ""
    table.insert(lines, { { icon_prefix .. cwd, "StartinatorCwd" } })
  end

  -- 4. Dynamic Greeting (optional)
  if opts.greeting then
    local greeting = utils.get_greeting()
    table.insert(lines, { { greeting, "StartinatorGreeting" } })
  end

  return {
    lines = lines,
    items = {},
  }
end

return M
