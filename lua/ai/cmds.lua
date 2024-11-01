local ChatDialog = require("ai.chat_dialog")

return {
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
