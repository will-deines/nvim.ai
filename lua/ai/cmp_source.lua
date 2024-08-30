local cmp = require("cmp")
local source = {}
local scan = require("plenary.scandir")

-- List of special commands
local special_commands = {
  { label = "/buf", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/file", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/dir", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/model", kind = cmp.lsp.CompletionItemKind.Keyword }, -- Add /model command
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
  return [[/.*]]
end

local function optimized_sort(items)
  table.sort(items, function(a, b)
    return a.label < b.label
  end)
end

local function get_directories(cwd)
  local dirs = {}
  scan.scan_dir(cwd, {
    hidden = true,
    respect_gitignore = true,
    only_dirs = true,
    on_insert = function(dir)
      table.insert(dirs, dir)
    end,
  })
  return dirs
end

local function fuzzy_match(input, str)
  local pattern = ".*" .. input:gsub(".", function(c)
    return c .. ".*"
  end)
  return str:match(pattern) ~= nil
end

local function handle_file_command(self, input, callback)
  local items = {}
  local file_cache = self.get_file_cache()
  local file_input = input:match("^/file%s+(.*)")
  for _, file in ipairs(file_cache) do
    if fuzzy_match(file_input, file) then
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
  callback({ items = items, isIncomplete = true })
end

local function handle_dir_command(input, callback)
  local items = {}
  local cwd = vim.fn.getcwd()
  local dir_input = input:match("^/dir%s+(.*)")
  local dirs = get_directories(cwd)
  for _, dir in ipairs(dirs) do
    if fuzzy_match(dir_input, dir) then
      local relative_path = vim.fn.fnamemodify(dir, ":.")
      table.insert(items, {
        label = string.format("/dir %s", relative_path),
        kind = cmp.lsp.CompletionItemKind.Folder,
        documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = string.format("Directory: %s", dir),
        },
      })
    end
  end
  optimized_sort(items)
  callback({ items = items, isIncomplete = true })
end

local function handle_buf_command(callback)
  local items = {}
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
  callback({ items = items, isIncomplete = true })
end

local function handle_model_command(callback)
  local items = {
    { label = "gpt-4o" },
    { label = "gpt-4o-mini" },
    { label = "claude-3-5-sonnet-20240620" },
    { label = "claude-3-haiku-20240307" },
    -- Add more models here
  }
  callback({ items = items, isIncomplete = true })
end

source.complete = function(self, request, callback)
  local input = string.sub(request.context.cursor_before_line, request.offset)
  print("Completion request input:", input) -- Debug print
  if input:match("^/buf%s*$") then
    handle_buf_command(callback)
  elseif input:match("^/file%s+.*") then
    handle_file_command(self, input, callback)
  elseif input:match("^/dir%s+.*") then
    handle_dir_command(input, callback)
  elseif input:match("^/model%s+.*") then
    print("Handling /model command") -- Debug print
    handle_model_command(callback)
  else
    callback({ items = {}, isIncomplete = true })
  end
end

return source
