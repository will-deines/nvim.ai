local cmp = require("blink.cmp")
local config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")
local function is_chat_dialog_buf()
  return vim.bo.filetype == config.FILE_TYPE
end
local function get_cwd_files(context)
  local cwd = context.opts.get_cwd(context)
  local files = vim.fn.globpath(cwd, "*", { nodir = true })
  if config.get("file_completion").respect_gitignore then
    files = vim.tbl_filter(function(file)
      return not vim.fn.match(file, config.get("file_completion").exclude_patterns)
    end, files)
  end
  return files
end
local function get_cwd_directories(context)
  local cwd = context.opts.get_cwd(context)
  local directories = vim.fn.globpath(cwd, "*", { onlydir = true })
  if config.get("file_completion").respect_gitignore then
    directories = vim.tbl_filter(function(dir)
      return not vim.fn.match(dir, config.get("file_completion").exclude_patterns)
    end, directories)
  end
  return directories
end
local function get_buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) ~= "" then
      table.insert(buffers, vim.api.nvim_buf_get_name(buf))
    end
  end
  return buffers
end
local function create_completion_item(command, context, item)
  return {
    label = item,
    kind = command.kind,
    detail = command.detail,
    documentation = { kind = "markdown", value = command.doc },
    insertText = item,
    textEdit = {
      newText = item,
      range = {
        start = { line = context.cursor[1] - 1, character = context.bounds.start_col - 1 },
        ["end"] = { line = context.cursor[1] - 1, character = context.bounds.end_col },
      },
    },
  }
end
local function get_completions(builtin_commands, dynamic_commands, ctx, callback)
  local items = {}
  local input = ctx:get_keyword()
  for id, command in pairs(builtin_commands) do
    if input:match("^" .. vim.pesc(command.label)) then
      table.insert(items, create_completion_item(command, ctx, command.label))
    end
  end
  for id, fn in pairs(dynamic_commands) do
    if input:match("^" .. vim.pesc(id)) then
      local dynamic_items = fn(ctx)
      for _, item in ipairs(dynamic_items) do
        table.insert(items, create_completion_item(builtin_commands[id:gsub("/", "")], ctx, item))
      end
    end
  end
  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end
local M = {}
function M.setup()
  cmp.setup({
    sources = {
      cmdline = function()
        return {}
      end, -- disable cmdline completions
      default = function(ctx)
        if not is_chat_dialog_buf() then
          return {}
        end
        local builtin_commands = {
          user = { label = "/user:", detail = "Start user message", doc = [[Start a new user message in the chat]] },
          assistant = {
            label = "/assistant:",
            detail = "Start assistant message",
            doc = [[Start a new assistant message in the chat]],
          },
          system = { label = "/system:", detail = "Set system prompt", doc = [[Set or change the system prompt]] },
          file = {
            label = "/file ",
            detail = "Reference file",
            kind = vim.lsp.protocol.CompletionItemKind.File,
            doc = [[Reference a file from the current directory]],
          },
          dir = {
            label = "/dir ",
            detail = "Reference directory",
            kind = vim.lsp.protocol.CompletionItemKind.Folder,
            doc = [[Reference a directory from the current working directory]],
          },
          buf = {
            label = "/buf ",
            detail = "Reference buffer",
            kind = vim.lsp.protocol.CompletionItemKind.Text,
            doc = [[Reference content from currently open buffers]],
          },
        }
        local dynamic_commands = {
          ["/file "] = get_cwd_files,
          ["/dir "] = get_cwd_directories,
          ["/buf "] = get_buffers,
        }
        return {
          {
            name = "nvimai",
            get_trigger_characters = function()
              return { "/" }
            end,
            get_completions = function(ctx, callback)
              get_completions(builtin_commands, dynamic_commands, ctx, callback)
            end,
            opts = {
              get_cwd = function(context)
                return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
              end,
            },
          },
        }
      end,
    },
    enabled = config.enabled,
  })
  -- Set up autocommands for chat dialog buffer
  vim.api.nvim_create_autocmd("FileType", {
    pattern = config.FILE_TYPE,
    callback = function()
      -- Set up keymaps for chat dialog
      local keymaps = config.get("keymaps")
      vim.keymap.set(
        "n",
        keymaps.send,
        ChatDialog.send,
        { noremap = true, silent = true, buffer = true, desc = "Send Message" }
      )
      vim.keymap.set(
        "n",
        keymaps.close,
        ChatDialog.close,
        { noremap = true, silent = true, buffer = true, desc = "Close Chat Dialog" }
      )
      vim.keymap.set(
        "n",
        keymaps.clear,
        ChatDialog.clear,
        { noremap = true, silent = true, buffer = true, desc = "Clear Chat" }
      )
    end,
  })
  return {}
end
return M
