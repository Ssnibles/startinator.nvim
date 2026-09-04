if vim.g.loaded_startinator then
  return
end
vim.g.loaded_startinator = 1

-- Register user commands
vim.api.nvim_create_user_command("Startinator", function()
  require("startinator").open()
end, { desc = "Open Startinator dashboard" })

vim.api.nvim_create_user_command("StartinatorClose", function()
  require("startinator").close()
end, { desc = "Close Startinator dashboard" })

vim.api.nvim_create_user_command("StartinatorToggle", function()
  require("startinator").toggle()
end, { desc = "Toggle Startinator dashboard" })

-- Auto-open on VimEnter when starting with an empty session
local group = vim.api.nvim_create_augroup("StartinatorAutoStart", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  nested = true,
  callback = function()
    local config = require("startinator.config")
    if config.options and config.options.auto_open == false then
      return
    end

    -- Skip if file arguments were passed
    if vim.fn.argc() ~= 0 then
      return
    end

    -- Skip if reading piped input from stdin
    if vim.g.started_with_stdin then
      return
    end

    -- Skip if restoring a session
    if vim.g.SessionLoad or vim.v.this_session ~= "" then
      return
    end

    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)

    -- Only open if buffer is completely unnamed, unmodified, and empty
    if name == "" and vim.bo[buf].buftype == "" and not vim.bo[buf].modified then
      local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
      if #lines <= 1 and (lines[1] == "" or lines[1] == nil) then
        require("startinator").open()
      end
    end
  end,
})
