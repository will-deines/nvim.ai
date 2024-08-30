local Config = require("ai.config")
local Assistant = require("ai.assistant")
local ChatDialog = require("ai.chat_dialog")
local Providers = require("ai.providers")
local CmpSource = require("ai.cmp_source")
local cmp = require("cmp")
local uv = vim.loop
local scan = require("plenary.scandir")
local M = {}

M.setup_keymaps = function()
  -- Global keymaps
  local keymaps = Config.get("keymaps")
  print(vim.inspect(keymaps)) -- Debug print to inspect the keymaps table
  vim.keymap.set({ "n", "v" }, keymaps.toggle, ChatDialog.toggle, { noremap = true, silent = true })
  vim.keymap.set("n", keymaps.inline_assist, ":NvimAIInlineAssist", { noremap = true, silent = true })
  vim.keymap.set("n", keymaps.accept_code, Assistant.accept_code, { noremap = true, silent = true })
  vim.keymap.set("n", keymaps.reject_code, Assistant.reject_code, { noremap = true, silent = true })
  -- Buffer-specific keymaps for ChatDialog
  local function set_chat_dialog_keymaps()
    local opts = { noremap = true, silent = true, buffer = true }
    vim.keymap.set("n", keymaps.close, ChatDialog.close, opts)
    vim.keymap.set("n", keymaps.send, ChatDialog.send, opts)
    vim.keymap.set("n", keymaps.clear, ChatDialog.clear, opts)
  end
  -- Create an autocommand to set ChatDialog keymaps when entering the chat-dialog buffer
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Config.FILE_TYPE,
    callback = set_chat_dialog_keymaps,
  })
  -- automatically setup Avante filetype to markdown
  vim.treesitter.language.register("markdown", Config.FILE_TYPE)
end

-- Cache for storing file list
local file_cache = {}
-- Function to populate the file cache asynchronously
local function populate_file_cache()
  local cwd = vim.fn.getcwd()
  file_cache = {} -- Clear the cache
  scan.scan_dir_async(cwd, {
    hidden = true,
    respect_gitignore = true,
    on_insert = function(file)
      table.insert(file_cache, file)
    end,
    on_exit = function()
      print("File cache populated:", vim.inspect(file_cache))
    end,
  })
end
-- Populate the cache when the Neovim window is launched
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    print("Populating file cache...")
    populate_file_cache()
  end,
})
-- Setup function to initialize the plugin
M.setup = function(opts)
  Config.setup(opts)
  -- Load the plugin's configuration
  ChatDialog:setup()
  Providers.setup()
  -- Register the custom source
  cmp.register_source("nvimai_cmp_source", CmpSource.new(M.get_file_cache))
  -- create commands
  local cmds = require("ai.cmds")
  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd.cmd, cmd.callback, cmd.opts)
  end
  M.setup_keymaps()
end
-- Function to get the file cache
M.get_file_cache = function()
  return file_cache
end
return M
