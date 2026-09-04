local M = {}

M.defaults = {
	-- Layout alignment: "center" (content block horizontally centered) or "left"
	align = "center",
	width = 46, -- Target width of the content block for aligned rules and hotkeys
	margin = 4, -- Left margin when align = "left"
	padding_top = 0, -- Minimum top padding (0 allows true vertical centering)

	-- Automatically open dashboard on Neovim startup if buffer is empty
	auto_open = true,

	-- Ordered sections to render
	sections = {
		"header",
		"shortcuts",
		"mru",
		"footer",
	},

	-- Header section
	header = {
		enabled = true,
		title = "  E O V I M", -- Modern title with Neovim icon
		cwd = true, -- Show current working directory path below title
		greeting = false, -- Dynamic greeting (optional)
	},

	-- Quick action shortcuts
	shortcuts = {
		enabled = true,
		title = "Actions", -- Section title divider
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
		title = "Recent", -- Section title divider
		limit = 5, -- Maximum number of recent files to show
		cwd_only = false, -- Only show files within current working directory
		show_icons = true, -- Show file type icons
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
		content = "hints", -- "hints" for navigation shortcuts, or custom string/function
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

	-- Highlight groups configuration (with default links)
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
--- @param opts table|nil
function M.setup(opts)
	local user_opts = opts or {}

	-- Backward compatibility: map old keymap names if present
	if user_opts.keymaps then
		if user_opts.keymaps.next_item and not user_opts.keymaps.next then
			user_opts.keymaps.next = user_opts.keymaps.next_item
		end
		if user_opts.keymaps.prev_item and not user_opts.keymaps.prev then
			user_opts.keymaps.prev = user_opts.keymaps.prev_item
		end
		if user_opts.keymaps.select_item and not user_opts.keymaps.select then
			user_opts.keymaps.select = user_opts.keymaps.select_item
		end
		if user_opts.keymaps.mouse_click and not user_opts.keymaps.mouse then
			user_opts.keymaps.mouse = user_opts.keymaps.mouse_click
		end
	end

	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts)
end

return M
