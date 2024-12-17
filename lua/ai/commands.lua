local ChatDialog = require("ai.chat_dialog")

--- Command registration and management
--- @class AI.Commands
local Commands = {}

local Events = require("ai.events")

-- Command definitions
local commands = {
  {
    cmd = "AIChat",
    callback = function()
      require("ai.chat_dialog").toggle()
    end,
    opts = {
      desc = "Toggle AI Chat Dialog",
    },
  },
  {
    cmd = "NvimAIToggleChatDialog",
    callback = function()
      ChatDialog.toggle()
    end,
    opts = {
      desc = "Insert code or rewrite a section",
    },
  },
  {
    cmd = "NvimAISelectModel",
    callback = function()
      ChatDialog.UpdateProviderAndModel()
    end,
    opts = {
      desc = "Select a model for the chat dialog",
    },
  },
}

function Commands.setup()
  for _, cmd in ipairs(commands) do
    local ok, err = pcall(vim.api.nvim_create_user_command, cmd.cmd, cmd.callback, cmd.opts)

    if not ok then
      Events.emit("command_setup_failed", {
        command = cmd.cmd,
        error = err,
      })
    end
  end
end

return Commands
