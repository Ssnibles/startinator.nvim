local M = {}

--- Default configuration
M.defaults = {
  -- Layout alignment: "center" (horizontally centered) or "left"
  align = "center",
  width = 46, -- Target width of the content block
  margin = 4, -- Left margin when align = "left"
  padding_top = 0, -- Minimum top padding (0 allows vertical centering)


  -- Automatically open dashboard on Neovim startup if buffer is empty
  auto_open = true,

  -- Ordered list of sections to render
  sections = {
    "header",
    "shortcuts",
    "mru",
    "footer",
  },

  -- Header section
  header = {
    enabled = true,
    title = "  N E O V I M", -- Modern title with Neovim icon
    cwd = true, -- Show current working directory path below title
    greeting = false, -- Dynamic greeting
  },

  -- Quick action shortcuts
  shortcuts = {
    enabled = true,
    title = "Actions",
    items = {
      { key = "f", icon = "󰈞", desc = "Find file", action = "find_files" },
      { key = "e", icon = "󰉓", desc = "File explorer", action = "oil" },
      { key = "n", icon = "󰝒", desc = "New file", action = "new_file" },
      { key = "g", icon = "󰊢", desc = "Live grep", action = "live_grep" },
      { key = "q", icon = "󰅚", desc = "Quit", action = "quit" },
    },
  },

  -- Most Recently Used (MRU) files
  mru = {
    enabled = true,
    title = "Recent",
    limit = 5,
    cwd_only = true,
    show_icons = true,
    ignore = {
      "%.git/",
      "COMMIT_EDITMSG",
      "MERGE_MSG",
      "/tmp/",
      "%.undodir/",
    },
  },

  -- Footer section
  footer = {
    enabled = true,
    content = "hints", -- "hints" for navigation shortcuts, or custom string/function/table
  },

  -- Buffer-local keymaps
  keymaps = {
    next = { "j", "<Down>", "<Tab>" },
    prev = { "k", "<Up>", "<S-Tab>" },
    select = { "<CR>", "<Space>", "l" },
    oil = { "e" },
    new_file = { "i", "a", "o" },
    quit = { "q", "<Esc>" },
    mouse = "<LeftMouse>",
  },

  -- Highlight groups configuration
  highlights = {
    Header = { link = "Title" },
    Cwd = { link = "Comment" },
    SectionTitle = { link = "Special" },
    SectionRule = { link = "Comment" },
    ShortcutKey = { link = "Number" },
    ShortcutIcon = { link = "Special" },
    ShortcutDesc = { link = "Normal" },
    MruIndex = { link = "Number" },
    MruIcon = { link = "Normal" },
    MruFilename = { link = "Directory" },
    MruPath = { link = "Comment" },
    Footer = { link = "Comment" },
  },
}

M.options = vim.deepcopy(M.defaults)

--- Set up user options with backward compatibility support
---@param opts table|nil
function M.setup(opts)
  local user_opts = opts or {}

  -- Backward compatibility: map deprecated keymap aliases if present
  if user_opts.keymaps then
    local km = user_opts.keymaps
    if km.next_item and not km.next then
      km.next = km.next_item
    end
    if km.prev_item and not km.prev then
      km.prev = km.prev_item
    end
    if km.select_item and not km.select then
      km.select = km.select_item
    end
    if km.mouse_click and not km.mouse then
      km.mouse = km.mouse_click
    end
    if km.explorer and not km.oil then
      km.oil = km.explorer
    end
  end

  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts)
end

return M
