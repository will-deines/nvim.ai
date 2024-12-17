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
  :with_dynamic_completion("/file", function()
    local files = vim.fn.glob(vim.fn.getcwd() .. "/*", true, true)
    return vim.tbl_filter(function(file)
      return vim.fn.isdirectory(file) == 0
    end, files)
  end)
  :with_dynamic_completion("/dir", function()
    local files = vim.fn.glob(vim.fn.getcwd() .. "/*", true, true)
    return vim.tbl_filter(function(file)
      return vim.fn.isdirectory(file) == 1
    end, files)
  end)
  :with_dynamic_completion("/buf", function()
    local buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        table.insert(buffers, vim.api.nvim_buf_get_name(buf))
      end
    end
    return buffers
  end)
  :build()
source.enabled = function()
  local is_enabled = vim.bo.filetype == "chat-dialog"
  require("ai.utils").debug("cmp_source enabled check: " .. tostring(is_enabled), { title = "NvimAI Completion" })
  return is_enabled
end
return source
