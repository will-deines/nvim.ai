local ChatDialog = require("ai.chat_dialog")
local Assistant = require("ai.assistant")
local code_block_navigator = require("ai.chat-dialog-handlers.code_block_navigator")

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
    cmd = "NvimAIInlineAssist",
    callback = function(opts)
      Assistant.inline(opts.args)
    end,
    opts = {
      desc = "Insert code or rewrite a section",
      range = true,
      nargs = "*",
    },
  },
  {
    cmd = "NvimAIAcceptCode",
    callback = function(opts)
      Assistant.accept_code()
    end,
    opts = {
      desc = "Accept generated code",
      range = true,
      nargs = "*",
    },
  },
  {
    cmd = "NvimAIRejectCode",
    callback = function(opts)
      Assistant.reject_code()
    end,
    opts = {
      desc = "Reject generated code",
      range = true,
      nargs = "*",
    },
  },
  {
    cmd = "NvimAINavigateCodeBlocks",
    callback = function()
      code_block_navigator.identify_and_navigate_code_blocks()
    end,
    opts = {
      desc = "Navigate and copy code blocks",
    },
  },
}
