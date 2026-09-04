# startinator.nvim 🚀

A minimal, distraction-free, and blazingly fast startpage (dashboard) for Neovim written in pure Lua. Designed with usability, speed, and sleek aesthetics first.

```
                   N E O V I M
                   ~/projects/my-app

                 ─ Actions ────────────────────────────────────
                 󰈞  Find file                                 f
                 󰝒  New file                                  n
                 󰊢  Live grep                                 g
                 󰅚  Quit                                      q

                 ─ Recent ─────────────────────────────────────
                 󰈔  lua/startinator/init.lua                  1
                 󰈔  lua/startinator/render.lua                2
                 󰈔  README.md                                 3

                    j/k navigate  ·  <cr> select  ·  q quit
```

---

## ✨ Features

- ⚡ **Sub-millisecond Speed**: Instant rendering (< 1ms) with zero overhead and zero external dependencies.
- 🧘 **Modern & Sleek Aesthetics**: Clean, balanced block centering, subtle horizontal rule dividers (`─ Actions ──`), right-aligned hotkeys, hidden filler tildes (`~`), and clean cursorline highlighting.
- 🚀 **Smart Pickers**: Automatically detects and uses `snacks.picker`, `fzf-lua`, `telescope`, `mini.pick`, or native Neovim fallbacks. Works out of the box with zero runtime errors on any setup.
- ⌨️ **Usability First**:
  - Direct instant hotkeys (`f`, `r`, `n`, `g`, `c`, `q`, `1`–`9`).
  - Constrained, wrapping navigation (`j`/`k`, `<Tab>`/`<S-Tab>`, `<Down>`/`<Up>`).
  - Immediate typing: press `i`, `a`, or `o` to open a new buffer in insert mode.
  - Mouse click support (`<LeftMouse>`).
- 🕒 **Fast MRU (Recent Files)**: Instant filesystem checks via `vim.uv.fs_stat`, ignores ephemeral files, aligns filename and path columns, and maps `1`–`9` hotkeys.
- 🛡️ **Polite & Safe Window Management**: Automatically preserves and restores your original window options (`number`, `relativenumber`, `signcolumn`, `fillchars`, etc.) when navigating to a file. Reuses empty startup buffers without leaving orphaned buffers.
- 🧩 **Extensible**: Clean chunk/span section pipeline with full backward compatibility for custom sections.

---

## 📥 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "josh/startinator.nvim",
  opts = {
    -- custom options (optional)
  },
}
```

### Using [mini.deps](https://github.com/echasnovski/mini.deps)

```lua
MiniDeps.add({
  source = "josh/startinator.nvim",
})
require("startinator").setup()
```

---

## ⚙️ Configuration & Defaults

Startinator is completely usable out of the box with zero configuration. All defaults can be overridden:

```lua
require("startinator").setup({
  -- Layout alignment: "center" (content block horizontally centered) or "left"
  align = "center",
  width = 46,      -- Target width of the content block for aligned rules and hotkeys
  margin = 4,      -- Left margin when align = "left"
  padding_top = 2, -- Minimum empty lines at top

  -- Automatically open when Neovim starts with an empty buffer
  auto_open = true,

  -- Ordered sections to render
  sections = {
    "header",
    "shortcuts",
    "mru",
    "footer",
  },

  -- Header settings
  header = {
    enabled = true,
    title = "  N E O V I M", -- Modern title string, or array of strings for ASCII art
    cwd = true,                 -- Show current working directory path below title
    greeting = false,           -- Dynamic time-of-day greeting (disabled by default)
  },

  -- Quick action shortcuts
  shortcuts = {
    enabled = true,
    title = "Actions",         -- Section title divider
    items = {
      { key = "f", icon = "󰈞", desc = "Find file", action = "find_files" },
      { key = "n", icon = "󰝒", desc = "New file", action = "new_file" },
      { key = "g", icon = "󰊢", desc = "Live grep", action = "live_grep" },
      { key = "q", icon = "󰅚", desc = "Quit", action = "quit" },
    },
  },

  -- Most Recently Used (MRU) files
  mru = {
    enabled = true,
    title = "Recent",          -- Section title divider
    limit = 5,                 -- Number of recent files to display
    cwd_only = false,          -- Filter to files in current working directory
    show_icons = true,         -- Show file type icons (mini.icons or nvim-web-devicons)
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
    content = "hints",         -- "hints" for navigation key hints, or custom string/function
  },

  -- Buffer-local keymaps
  keymaps = {
    next = { "j", "<Down>", "<Tab>" },
    prev = { "k", "<Up>", "<S-Tab>" },
    select = { "<CR>", "<Space>", "l" },
    new_file = { "i", "a", "o" },
    quit = { "q", "<Esc>" },
    mouse = "<LeftMouse>",
  },

  -- Highlight groups (default links to standard Vim groups)
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

---

## 🎮 Commands & Navigation

### Commands

- `:Startinator` — Open dashboard.
- `:StartinatorClose` — Close dashboard (returns to previous buffer or quits if only buffer).
- `:StartinatorToggle` — Toggle dashboard open / closed.

### Keybindings inside the Dashboard

| Key | Action |
| :--- | :--- |
| `j` / `<Down>` / `<Tab>` | Jump to next interactive item (wraps around) |
| `k` / `<Up>` / `<S-Tab>` | Jump to previous interactive item (wraps around) |
| `<CR>` / `<Space>` / `l` | Activate item under cursor |
| `f`, `r`, `n`, `g`, `c`, `q` | Immediate action hotkeys |
| `1` – `9` | Immediately open corresponding recent file |
| `i` / `a` / `o` | Instantly create a new buffer and enter insert mode |
| `q` / `<Esc>` | Close dashboard or quit Neovim |
| `<LeftMouse>` | Click to activate any item |

---

## 🛠️ Adding Custom Sections

You can add custom sections by providing a module name, a table with a `render` function, or a function directly:

```lua
local quote_section = {
  render = function(config)
    return {
      lines = {
        { { "💡 ", "Special" }, { '"Simplicity is prerequisite for reliability."', "Comment" } },
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

---

## 📄 License

MIT
