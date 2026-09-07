# startinator.nvim

A minimal startpage for Neovim written in Lua.

## Features

- Automatic picker detection: uses `snacks.picker`, `fzf-lua`, `telescope`, `mini.pick`, or built-in fallbacks.
- Recent files (MRU): displays recent files with dimmed directory paths, highlighted filenames, and single-key number shortcuts.
- Direct keybindings: trigger actions and recent files directly without pressing Enter.
- Window option preservation: saves and restores window options (`number`, `relativenumber`, `signcolumn`, `fillchars`, etc.) when opening files.
- Modular layout: reorder sections or add custom render functions.

## Installation

### lazy.nvim

```lua
{
  "josh/startinator.nvim",
  opts = {},
}
```

### mini.deps

```lua
MiniDeps.add({ source = "josh/startinator.nvim" })
require("startinator").setup()
```

## Configuration

Default options:

```lua
require("startinator").setup({
  -- Content block alignment: "center" or "left"
  align = "center",
  width = 46,      -- Target width of the content block
  margin = 4,      -- Left margin when align = "left"
  padding_top = 0, -- Minimum top padding (0 centers vertically)

  -- Open on startup when Neovim starts with an empty buffer
  auto_open = true,

  -- Ordered list of sections to render
  sections = {
    "header",
    "shortcuts",
    "mru",
    "footer",
  },

  -- Header settings
  header = {
    enabled = true,
    title = "  N E O V I M", -- Title string or table of strings for ASCII art
    cwd = true,                 -- Show current working directory below title
    greeting = false,           -- Time-of-day greeting
  },

  -- Action shortcuts
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

  -- Recent files (MRU)
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

  -- Footer settings
  footer = {
    enabled = true,
    content = "hints", -- "hints" for key hints, or a custom string / function
  },

  -- Keybindings inside the dashboard buffer
  keymaps = {
    next = { "j", "<Down>", "<Tab>" },
    prev = { "k", "<Up>", "<S-Tab>" },
    select = { "<CR>", "<Space>", "l" },
    oil = { "e" },
    new_file = { "i", "a", "o" },
    quit = { "q", "<Esc>" },
    mouse = "<LeftMouse>",
  },

  -- Highlight groups
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
})
```

## Commands

- `:Startinator` — Open the dashboard.
- `:StartinatorClose` — Close the dashboard.
- `:StartinatorToggle` — Toggle the dashboard open or closed.

## Keybindings

| Key | Action |
| :--- | :--- |
| `j` / `<Down>` / `<Tab>` | Move to next item (wraps) |
| `k` / `<Up>` / `<S-Tab>` | Move to previous item (wraps) |
| `<CR>` / `<Space>` / `l` | Open item under cursor |
| `f`, `e`, `n`, `g`, `q` | Run action shortcut (`e` runs `oil.toggle_float()`) |
| `1` – `9` | Open recent file by index |
| `i` / `a` / `o` | Create a new buffer and enter insert mode |
| `q` / `<Esc>` | Close dashboard or quit Neovim |
| `<LeftMouse>` | Activate clicked item |

## Custom Sections

Add custom sections by providing a table with a `render(config)` function or a function directly:

```lua
local quote_section = {
  render = function(config)
    return {
      lines = {
        { { "Simplicity is prerequisite for reliability.", "Comment" } },
      },
      items = {},
    }
  end,
}

require("startinator").setup({
  sections = {
    "header",
    "shortcuts",
    quote_section,
    "footer",
  },
})
```

Interactive items can be included in custom sections:

```lua
local project_section = {
  render = function(config)
    return {
      lines = {
        { { "Projects", "StartinatorShortcutDesc" } },
      },
      items = {
        {
          line_idx = 1,
          key = "p",
          action = function()
            -- custom action logic
          end,
        },
      },
    }
  end,
}
```

## License

MIT
