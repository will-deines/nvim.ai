local source = require("ai.completion.source_builder")
  .new("NvimAI")
  :with_filetype("chat-dialog")
  :with_trigger_chars({ "/", " " })
  :with_command(
    "file",
    "/file",
    "Complete file paths",
    [[Complete file paths from current directory
Use this to browse and select files from the current working directory.]]
  )
  :with_command(
    "buf",
    "/buf",
    "Complete buffers",
    [[Complete paths from open buffers
Use this to reference content from currently open buffers.]]
  )
  :with_command(
    "dir",
    "/dir",
    "Complete directories",
    [[Complete directory paths
Use this to browse and select directories from the current working directory.]]
  )
  :build()

return source
