--- Keymap configuration and management
--- @class AI.Keymaps
local Keymaps = {}

local Events = require("ai.events")
local Config = require("ai.config")
local ChatDialog = require("ai.chat_dialog")

--- Setup all keymaps
function Keymaps.setup()
  Events.emit("keymap_setup_start", { type = "global" })

  -- Setup global keymaps
  Keymaps._setup_global_keymaps()

  -- Setup buffer-local keymaps
  Keymaps._setup_buffer_keymaps()

  -- Register filetype
  Keymaps._register_filetype()

  Events.emit("keymap_setup_complete", { type = "global" })
end

function Keymaps._setup_global_keymaps()
  local keymaps = Config.get("keymaps")

  local global_keymap_configs = {
    {
      modes = { "n", "v" },
      key = keymaps.toggle,
      callback = ChatDialog.toggle,
      desc = "Toggle AI Chat Dialog",
    },
    {
      modes = { "n" },
      key = keymaps.select_model,
      callback = ChatDialog.UpdateProviderAndModel,
      desc = "Select AI Model",
    },
  }

  for _, keymap in ipairs(global_keymap_configs) do
    local ok, err = pcall(
      vim.keymap.set,
      keymap.modes,
      keymap.key,
      keymap.callback,
      { noremap = true, silent = true, desc = keymap.desc }
    )

    if not ok then
      Events.emit("keymap_error", {
        type = "global",
        key = keymap.key,
        error = err,
      })
    end
  end
end

function Keymaps._setup_buffer_keymaps()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Config.FILE_TYPE,
    callback = function()
      Events.emit("keymap_setup_start", { type = "chat_dialog" })

      local keymaps = Config.get("keymaps")
      local opts = { noremap = true, silent = true, buffer = true }

      local keymap_configs = {
        { mode = "n", key = keymaps.close, callback = ChatDialog.close, desc = "Close Chat Dialog" },
        { mode = "n", key = keymaps.send, callback = ChatDialog.send, desc = "Send Message" },
        { mode = "n", key = keymaps.clear, callback = ChatDialog.clear, desc = "Clear Chat" },
      }

      for _, keymap in ipairs(keymap_configs) do
        local ok, err = pcall(
          vim.keymap.set,
          keymap.mode,
          keymap.key,
          keymap.callback,
          vim.tbl_extend("force", opts, { desc = keymap.desc })
        )

        if not ok then
          Events.emit("keymap_error", {
            type = "chat_dialog",
            key = keymap.key,
            error = err,
          })
        end
      end

      Events.emit("keymap_setup_complete", { type = "chat_dialog" })
    end,
  })
end

function Keymaps._register_filetype()
  local ok, err = pcall(vim.treesitter.language.register, "markdown", Config.FILE_TYPE)
  if not ok then
    Events.emit("treesitter_error", {
      operation = "register_language",
      error = err,
    })
  end
end

return Keymaps
