local Config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")
local Providers = require("ai.providers")
local blink = require("blink.cmp")

local M = {}

M.setup_keymaps = function()
  local keymaps = Config.get("keymaps")
  vim.keymap.set({ "n", "v" }, keymaps.toggle, ChatDialog.toggle, { noremap = true, silent = true })
  vim.keymap.set("n", keymaps.select_model, function()
    ChatDialog.UpdateProviderAndModel()
  end, { noremap = true, silent = true })

  local function set_chat_dialog_keymaps()
    local opts = { noremap = true, silent = true, buffer = true }
    vim.keymap.set("n", keymaps.close, ChatDialog.close, opts)
    vim.keymap.set("n", keymaps.send, ChatDialog.send, opts)
    vim.keymap.set("n", keymaps.clear, ChatDialog.clear, opts)
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = Config.FILE_TYPE,
    callback = set_chat_dialog_keymaps,
  })

  vim.api.nvim_create_user_command("TestNvimAICompletion", function()
    print("Testing NvimAI completion")
    local blink_local = require("blink.cmp")
    print("Available sources:", vim.inspect(blink.get_sources()))
    -- Try to trigger completion manually
    blink_local.show()
  end, {})

  vim.treesitter.language.register("markdown", Config.FILE_TYPE)
end

local function setup_completion()
  -- Get the current blink.cmp config with null check
  ---@type LazyPlugin?
  local plugin_config = require("lazy.core.config").plugins["blink.cmp"]
  if not plugin_config or not plugin_config.opts then
    vim.notify("blink.cmp config not found, skipping completion setup", vim.log.levels.WARN)
    return
  end

  -- Get default configs
  local default_keymap = require("blink.cmp.config.keymap").default
  local default_completion = require("blink.cmp.config.completion").default
  local default_signature = require("blink.cmp.config.signature").default
  local default_snippets = require("blink.cmp.config.snippets").default
  local default_appearance = require("blink.cmp.config.appearance").default

  ---@type blink.cmp.Config
  local current_config = {
    enabled = function()
      return true
    end,
    keymap = default_keymap,
    completion = {
      keyword = default_completion.keyword,
      trigger = vim.tbl_deep_extend("force", default_completion.trigger, {
        show_on_keyword = true,
        show_on_trigger_character = true,
        show_on_blocked_trigger_characters = { " ", "\n", "\t" },
        show_on_accept_on_trigger_character = true,
        show_on_insert_on_trigger_character = true,
      }),
      list = default_completion.list,
      accept = default_completion.accept,
      menu = default_completion.menu,
      documentation = default_completion.documentation,
      ghost_text = default_completion.ghost_text,
    },

    sources = {
      completion = {
        enabled_providers = function(ctx)
          if not ctx or not ctx.bufnr then
            return {}
          end
          local ft = vim.bo[ctx.bufnr].filetype
          if ft == "chat-dialog" then
            return { "nvimai", "path", "buffer" }
          end
          return {}
        end,
      },
      providers = {
        nvimai = {
          name = "NvimAI",
          module = "ai.cmp_source",
          enabled = function(ctx)
            return vim.bo[ctx.bufnr].filetype == "chat-dialog"
          end,
          transform_items = function(_, items)
            return items
          end,
          should_show_items = function()
            return true
          end,
          max_items = function()
            return 200
          end,
          min_keyword_length = function()
            return 1
          end,
          fallback_for = function()
            return {}
          end,
          score_offset = function()
            return 0
          end,
          opts = {
            completion = {
              keyword_pattern = [[\%(/[a-zA-Z]*\)]],
              trigger = {
                characters = { "/" },
                show_on_keyword = true,
                show_on_trigger_character = true,
              },
            },
          },
          new = function(config)
            return {
              enabled = config.enabled,
              transform_items = config.transform_items,
              should_show_items = config.should_show_items,
              max_items = config.max_items,
              min_keyword_length = config.min_keyword_length,
              fallback_for = config.fallback_for,
              score_offset = config.score_offset,
            }
          end,
        },
        path = {
          name = "Path",
          module = "blink.cmp.sources.path",
          score_offset = function()
            return 3
          end,
          opts = {
            completion = {
              keyword_pattern = [[\%(\/file\s\+\|\/dir\s\+\)\zs[^[:space:]*]],
              trigger = {
                characters = { "/", " " },
                show_on_keyword = true,
                show_on_trigger_character = true,
              },
            },
          },
          new = function(config)
            return {
              enabled = function(ctx)
                local line = ctx.cursor_line:sub(1, ctx.cursor.col)
                return line:match("^/file%s+") or line:match("^/dir%s+")
              end,
              transform_items = function(_, items)
                return items
              end,
              should_show_items = function()
                return true
              end,
              max_items = function()
                return nil
              end,
              min_keyword_length = function()
                return 0
              end,
              fallback_for = function()
                return {}
              end,
              score_offset = config.score_offset,
            }
          end,
        },
        buffer = {
          name = "Buffer",
          module = "blink.cmp.sources.buffer",
          opts = {
            completion = {
              keyword_pattern = [[\%(\/buf\s\+\)\zs[^[:space:]*]],
              trigger = {
                characters = { "/", " " },
                show_on_keyword = true,
                show_on_trigger_character = true,
              },
            },
          },
          new = function(config)
            return {
              enabled = function(ctx)
                local line = ctx.cursor_line:sub(1, ctx.cursor.col)
                return line:match("^/buf%s+")
              end,
              transform_items = function(_, items)
                return items
              end,
              should_show_items = function()
                return true
              end,
              max_items = function()
                return nil
              end,
              min_keyword_length = function()
                return 0
              end,
              fallback_for = function()
                return {}
              end,
              score_offset = function()
                return 0
              end,
            }
          end,
        },
      },
    },
    signature = default_signature,
    snippets = default_snippets,
    appearance = default_appearance,
  }

  -- Add debug command
  vim.api.nvim_create_user_command("DebugNvimAICompletion", function()
    if vim.bo.filetype ~= Config.FILE_TYPE then
      vim.notify("This command only works in chat-dialog buffers", vim.log.levels.WARN)
      return
    end
    print("Current providers:", vim.inspect(current_config.sources.providers))
    print("Current filetype:", vim.bo.filetype)
    print("Expected filetype:", Config.FILE_TYPE)
    -- Check if our source is available
    local source = require("ai.cmp_source").new()
    print("Source available:", source:is_available())
  end, {})

  -- Apply the updated configuration
  local ok, err = pcall(function()
    require("blink.cmp.config").merge_with(current_config)
  end)
  if not ok then
    vim.notify("Failed to setup blink.cmp: " .. tostring(err), vim.log.levels.ERROR)
  end
end

M.setup = function(opts)
  Config.setup(opts)
  ChatDialog:setup()
  Providers.setup()

  -- Initialize completion
  setup_completion()

  -- Create commands
  local cmds = require("ai.cmds")
  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd.cmd, cmd.callback, cmd.opts)
  end

  -- Setup keymaps
  M.setup_keymaps()
end

return M
