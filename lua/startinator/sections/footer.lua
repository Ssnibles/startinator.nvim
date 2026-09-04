local M = {}

--- Render footer section
--- @param config table
--- @return table
function M.render(config)
  local opts = config.footer
  if not opts or not opts.enabled then
    return { lines = {}, items = {} }
  end

  local block_width = config._resolved_width or config.width or 46
  local content = opts.content

  if content == "hints" or content == nil then
    local hint_str = "j/k navigate  ·  <cr> select  ·  q quit"
    local hint_w = vim.fn.strdisplaywidth(hint_str)
    local pad = math.max(0, math.floor((block_width - hint_w) / 2))
    return {
      lines = {
        { { string.rep(" ", pad) .. hint_str, "StartinatorFooter" } },
      },
      items = {},
    }
  end

  if type(content) == "function" then
    local ok, res = pcall(content)
    if ok then
      content = res
    else
      content = nil
    end
  end

  if not content then
    return { lines = {}, items = {} }
  end

  local lines = {}
  if type(content) == "string" then
    table.insert(lines, { { content, "StartinatorFooter" } })
  elseif type(content) == "table" then
    for _, l in ipairs(content) do
      if type(l) == "string" then
        table.insert(lines, { { l, "StartinatorFooter" } })
      elseif type(l) == "table" then
        table.insert(lines, l)
      end
    end
  end

  return {
    lines = lines,
    items = {},
  }
end

return M
