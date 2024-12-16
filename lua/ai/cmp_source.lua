local source = {}
local Config = require("ai.config")

source.new = function()
  local self = {
    name = "nvimai",
  }
  function self:is_available()
    return vim.bo.filetype == Config.FILE_TYPE
  end
  function self:complete(_, callback)
    callback({
      items = {
        {
          label = "/file",
          kind = vim.lsp.protocol.CompletionItemKind.Keyword,
          documentation = {
            kind = "markdown",
            value = "Complete file paths from current directory",
          },
        },
        {
          label = "/buf",
          kind = vim.lsp.protocol.CompletionItemKind.Keyword,
          documentation = {
            kind = "markdown",
            value = "Complete buffer paths",
          },
        },
        {
          label = "/dir",
          kind = vim.lsp.protocol.CompletionItemKind.Keyword,
          documentation = {
            kind = "markdown",
            value = "Complete directory paths",
          },
        },
      },
    })
  end
  return self
end
return source
