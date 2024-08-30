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

  -- Add debug prints before each keymap set
  print("Setting toggle keymap")
  print("ChatDialog.toggle:", ChatDialog.toggle)
  vim.keymap.set({ "n", "v" }, keymaps.toggle, ChatDialog.toggle, { noremap = true, silent = true })

  print("Setting inline_assist keymap")
  print("Assistant.inline:", Assistant.inline)
  vim.keymap.set("n", keymaps.inline_assist, ":NvimAIInlineAssist", { noremap = true, silent = true })

  print("Setting accept_code keymap")
  print("Assistant.accept_code:", Assistant.accept_code)
  vim.keymap.set("n", keymaps.accept_code, Assistant.accept_code, { noremap = true, silent = true })

  print("Setting reject_code keymap")
  print("Assistant.reject_code:", Assistant.reject_code)
  vim.keymap.set("n", keymaps.reject_code, Assistant.reject_code, { noremap = true, silent = true })

  -- Buffer-specific keymaps for ChatDialog
  local function set_chat_dialog_keymaps()
    local opts = { noremap = true, silent = true, buffer = true }
    print("Setting close keymap")
    print("ChatDialog.close:", ChatDialog.close)
    vim.keymap.set("n", keymaps.close, ChatDialog.close, opts)

    print("Setting send keymap")
    print("ChatDialog.send:", ChatDialog.send)
    vim.keymap.set("n", keymaps.send, ChatDialog.send, opts)

    print("Setting clear keymap")
    print("ChatDialog.clear:", ChatDialog.clear)
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

-- Function to set keymaps for code block navigator
local function setup_code_block_navigator_keymaps()
  local function navigate_code_blocks(code_blocks)
    local current_index = 1
    local function move_to_next_block()
      if current_index > #code_blocks then
        current_index = 1
      end
      local block = code_blocks[current_index]
      vim.api.nvim_win_set_cursor(0, { block.start, 0 })
      current_index = current_index + 1
    end
    print("Setting keymap for 'n' key")
    vim.api.nvim_set_keymap("n", "n", ":lua move_to_next_block()<CR>", { noremap = true, silent = true })
  end

  local function yank_and_exit()
    vim.api.nvim_command("normal! V")
    vim.api.nvim_command("normal! y")
    vim.api.nvim_command("normal! :noh<CR>")
    vim.api.nvim_del_keymap("n", "n")
  end

  print("Setting keymap for '<leader>cb' key")
  vim.api.nvim_set_keymap(
    "n",
    "<leader>cb",
    ':lua require("ai.code_block_navigator").identify_and_navigate_code_blocks()<CR>',
    { noremap = true, silent = true }
  )
end

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
  setup_code_block_navigator_keymaps()
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

-- Function to get the file cache
M.get_file_cache = function()
  return file_cache
end

return M
