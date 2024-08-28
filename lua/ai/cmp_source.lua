local cmp = require("cmp")
local source = {}
local scan = require("plenary.scandir")

-- List of special commands
local special_commands = {
  { label = "/system", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/you", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/buf", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/file", kind = cmp.lsp.CompletionItemKind.Keyword },
  { label = "/dir", kind = cmp.lsp.CompletionItemKind.Keyword },
}

source.new = function(get_file_cache)
  local self = setmetatable({}, { __index = source })
  self.get_file_cache = get_file_cache
  return self
end

source.get_trigger_characters = function()
  return { "/", " " }
end

source.get_keyword_pattern = function()
  return [[\%(/\k*\)]]
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
  if input:match("^/file%s*$") then
    -- Handle /file command only after a space
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
  elseif input:match("^/file%s+.*") then
    -- Handle /file command with fuzzy matching
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
  end
  optimized_sort(items)
  callback({ items = items, isIncomplete = true })
end

local function handle_dir_command(input, callback)
  local items = {}
  local cwd = vim.fn.getcwd()
  if input:match("^/dir%s*$") then
    -- Handle /dir command only after a space
    local dirs = get_directories(cwd)
    for _, dir in ipairs(dirs) do
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
  elseif input:match("^/dir%s+.*") then
    -- Handle /dir command with fuzzy matching
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

local function handle_you_command(callback)
  local items = {
    { label = "/you", kind = cmp.lsp.CompletionItemKind.Keyword },
  }
  optimized_sort(items)
  callback({ items = items, isIncomplete = true })
end

local function handle_system_command(callback)
  local items = {
    { label = "/system", kind = cmp.lsp.CompletionItemKind.Keyword },
  }
  optimized_sort(items)
  callback({ items = items, isIncomplete = true })
end

local function handle_special_commands(callback)
  local items = {}
  for _, command in ipairs(special_commands) do
    table.insert(items, command)
  end
  optimized_sort(items)
  callback({ items = items, isIncomplete = true })
end

source.complete = function(self, request, callback)
  local input = string.sub(request.context.cursor_before_line, request.offset)
  print("Completion request input:", input)
  if input == "/" then
    -- Show special commands when input is exactly "/"
    handle_special_commands(callback)
  elseif input:match("^/buf%s*$") then
    -- Handle /buf command
    handle_buf_command(callback)
  elseif input:match("^/file%s*$") then
    -- Delegate to handle_file_command
    handle_file_command(self, input, callback)
  elseif input:match("^/dir%s*$") then
    -- Delegate to handle_dir_command
    handle_dir_command(input, callback)
  elseif input:match("^/you%s*$") then
    -- Handle /you command
    handle_you_command(callback)
  elseif input:match("^/system%s*$") then
    -- Handle /system command
    handle_system_command(callback)
  else
    -- Handle other special commands
    handle_special_commands(callback)
  end
end

return source
