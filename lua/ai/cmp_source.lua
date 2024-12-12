local cmp = require("cmp")
local source = {}
local scan = require("plenary.scandir")

local function should_exclude(file_path, exclude_patterns)
  -- Convert to relative path for consistent matching
  local relative_path = vim.fn.fnamemodify(file_path, ":.")

  for _, pattern in ipairs(exclude_patterns) do
    -- Check if any parent directory matches the exclude pattern
    local parts = vim.split(relative_path, "/")
    local current_path = ""

    for _, part in ipairs(parts) do
      current_path = current_path .. (current_path == "" and "" or "/") .. part
      if current_path:match(vim.fn.glob2regpat(pattern)) then
        return true
      end
    end
  end
  return false
end

local function get_directories(cwd)
  local config = require("ai.config")
  local exclude_patterns = config.get("file_completion").exclude_patterns
  local dirs = {}

  -- Track directories to skip
  local skip_dirs = {}

  scan.scan_dir(cwd, {
    hidden = true,
    respect_gitignore = true,
    only_dirs = true,
    on_insert = function(dir)
      -- Skip if parent directory was excluded
      for skip_dir in pairs(skip_dirs) do
        if dir:match("^" .. vim.pesc(skip_dir)) then
          return
        end
      end

      if should_exclude(dir, exclude_patterns) then
        skip_dirs[dir] = true
        return
      end

      table.insert(dirs, dir)
    end,
  })

  return dirs
end

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
  local config = require("ai.config")
  local exclude_patterns = config.get("file_completion").exclude_patterns
  local dirs = {}

  scan.scan_dir(cwd, {
    hidden = true,
    respect_gitignore = true,
    only_dirs = true,
    on_insert = function(dir)
      local relative_path = vim.fn.fnamemodify(dir, ":.")
      if not should_exclude(relative_path, exclude_patterns) then
        table.insert(dirs, dir)
      end
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
    {
      label = "/model gpt-4o",
      kind = cmp.lsp.CompletionItemKind.Keyword,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = "Model: gpt-4o",
      },
    },
    {
      label = "/model gpt-4o-mini",
      kind = cmp.lsp.CompletionItemKind.Keyword,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = "Model: gpt-4o-mini",
      },
    },
    {
      label = "/model claude-3-5-sonnet-20240620",
      kind = cmp.lsp.CompletionItemKind.Keyword,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = "Model: claude-3-5-sonnet-20240620",
      },
    },
    {
      label = "/model claude-3-haiku-20240307",
      kind = cmp.lsp.CompletionItemKind.Keyword,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = "Model: claude-3-haiku-20240307",
      },
    },
    {
      label = "/model gemini-1.5-flash",
      kind = cmp.lsp.CompletionItemKind.Keyword,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = "Model: gemini-1.5-flash",
      },
    },
    {
      label = "/model gemini-1.5-pro",
      kind = cmp.lsp.CompletionItemKind.Keyword,
      documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = "Model: gemini-1.5-pro",
      },
    },
    -- Add more models here
  }
  optimized_sort(items)
  callback({ items = items, isIncomplete = true })
end

source.complete = function(self, request, callback)
  local input = string.sub(request.context.cursor_before_line, request.offset)
  if input:match("^/buf%s*$") then
    handle_buf_command(callback)
  elseif input:match("^/file%s+.*") then
    handle_file_command(self, input, callback)
  elseif input:match("^/dir%s+.*") then
    handle_dir_command(input, callback)
  elseif input:match("^/model%s+.*") then
    handle_model_command(callback)
  else
    callback({ items = {}, isIncomplete = true })
  end
end

return source
