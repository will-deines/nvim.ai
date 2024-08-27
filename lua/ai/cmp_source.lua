-- source.lu
-- source.lua
local cmp = require("cmp")
local source = {}
-- List of special commands
local special_commands = {
  { label = "/system", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/you", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/buf", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/file", kind = cmp.lsp.CompletionItemKind.Keyword },
}
source.new = function(get_file_cache)
  local self = setmetatable({}, { __index = source })
  self.get_file_cache = get_file_cache
  return self
end
source.get_trigger_characters = function()
  return { "/" }
end
source.get_keyword_pattern = function()
  return [[\%(/\k*\)]]
end
local function optimized_sort(items)
  table.sort(items, function(a, b)
    return a.label < b.label
  end)
end
source.complete = function(self, request, callback)
  local input = string.sub(request.context.cursor_before_line, request.offset)
  local items = {}
  local cwd = vim.fn.getcwd()
  print("Completion request input:", input)
  if input:match("^/buf") then
    -- Handle /buf command
    local buffers = vim.api.nvim_list_bufs()
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" then
          local short_name = vim.fn.fnamemodify(name, ":t")
          table.insert(items, {
            label = string.format("/buf %d: %s", bufnr, short_name),
            kind = cmp.lsp.CompletionItemKind.File,
            data = { bufnr = bufnr },
            documentation = {
              kind = cmp.lsp.MarkupKind.Markdown,
              value = string.format("Buffer: %d\nFull path: %s", bufnr, name),
            },
          })
        end
      end
    end
    optimized_sort(items)
    print("Buffer items:", vim.inspect(items))
    callback({ items = items, isIncomplete = true })
  elseif input:match("^/file%s*") then
    -- Handle /file command
    local file_input = input:match("^/file%s*(.*)")
    print("File input:", file_input)
    local file_cache = self.get_file_cache()
    if file_input == "" then
      -- Show directories first
      for _, file in ipairs(file_cache) do
        local relative_path = vim.fn.fnamemodify(file, ":.")
        table.insert(items, {
          label = string.format("/file %s", relative_path),
          kind = cmp.lsp.CompletionItemKind.File,
          documentation = {
            kind = cmp.lsp.MarkupKind.Markdown,
            value = string.format("File: %s", file),
          },
        })
      end
      optimized_sort(items)
      print("File items:", vim.inspect(items))
      callback({ items = items, isIncomplete = true })
    else
      -- Use the cache for file completion
      for _, file in ipairs(file_cache) do
        if file:find(file_input, 1, true) then
          local relative_path = vim.fn.fnamemodify(file, ":.")
          table.insert(items, {
            label = string.format("/file %s", relative_path),
            kind = cmp.lsp.CompletionItemKind.File,
            documentation = {
              kind = cmp.lsp.MarkupKind.Markdown,
              value = string.format("File: %s", file),
            },
          })
        end
      end
      optimized_sort(items)
      print("File items:", vim.inspect(items))
      callback({ items = items, isIncomplete = true })
    end
  else
    -- Handle other special commands
    for _, command in ipairs(special_commands) do
      if command.label:find(input, 1, true) == 1 then
        print("Adding special command to items:", command.label)
        table.insert(items, command)
      end
    end
    optimized_sort(items)
    print("Special command items:", vim.inspect(items))
    callback({ items = items, isIncomplete = true })
  end
end
return source
