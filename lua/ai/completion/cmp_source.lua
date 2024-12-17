local source = require("ai.completion.source_builder")
  .new("NvimAI")
  :with_filetype("chat-dialog")
  :with_trigger_chars({ "/" })
  :with_command("user", "/user:", "Start user message", [[Start a new user message in the chat]])
  :with_command("assistant", "/assistant:", "Start assistant message", [[Start a new assistant message in the chat]])
  :with_command("system", "/system:", "Set system prompt", [[Set or change the system prompt]])
  :with_command("file", "/file ", "Reference file", [[Reference a file from the current directory]])
  :with_command("buf", "/buf ", "Reference buffer", [[Reference content from currently open buffers]])
  :with_command("dir", "/dir ", "Reference directory", [[Reference a directory from the current working directory]])
  :build()

return source
