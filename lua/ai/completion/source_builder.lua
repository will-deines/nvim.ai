--- @class SourceBuilder
--- @field private _config table
--- @field private _commands table<string, {label: string, detail: string, doc: string}>
local SourceBuilder = {}
SourceBuilder.__index = SourceBuilder
function SourceBuilder.new(name)
  return setmetatable({
    _config = {
      name = name,
      cache = {},
      resolved_cache = {},
      MAX_CACHE_SIZE = 1000,
    },
    _commands = {},
    _dynamic_completions = {},
  }, SourceBuilder)
end
function SourceBuilder:with_module(module)
  self._config.module = module
  return self
end
function SourceBuilder:with_command(id, label, detail, doc)
  self._commands[id] = {
    label = label,
    detail = detail,
    doc = doc,
  }
  return self
end
function SourceBuilder:with_dynamic_completion(id, fn)
  self._dynamic_completions[id] = fn
  return self
end
function SourceBuilder:with_trigger_chars(chars)
  self._config.trigger_chars = chars
  return self
end
function SourceBuilder:with_filetype(ft)
  self._config.filetype = ft
  return self
end
function SourceBuilder:build()
  assert(self._config.name, "Source name required")
  assert(self._config.filetype, "Source filetype required")
  local source = {}
  source.cache = {}
  source.resolved_cache = {}
  source.name = self._config.name
  function source:enabled()
    return vim.bo.filetype == self._config.filetype
  end
  function source:get_trigger_characters()
    return self._config.trigger_chars or {}
  end
  local function cleanup_caches(self)
    if vim.tbl_count(self.cache) > self._config.MAX_CACHE_SIZE then
      self.cache = {}
    end
    if vim.tbl_count(self.resolved_cache) > self._config.MAX_CACHE_SIZE then
      self.resolved_cache = {}
    end
  end
  local function create_completion_item(command, context)
    return {
      label = command.label,
      kind = vim.lsp.protocol.CompletionItemKind.Keyword,
      detail = command.detail,
      documentation = {
        kind = "markdown",
        value = command.doc,
      },
      insertText = command.label,
      textEdit = {
        newText = command.label,
        range = {
          start = { line = context.cursor[1] - 1, character = context.bounds.start_col - 1 },
          ["end"] = { line = context.cursor[1] - 1, character = context.bounds.end_col },
        },
      },
      source_id = self._config.name:lower(),
      source_name = self._config.name,
      cursor_column = context.cursor[2],
      score_offset = 0,
    }
  end
  local function create_dynamic_completion_item(item, context, id)
    return {
      label = item,
      kind = vim.lsp.protocol.CompletionItemKind.File,
      detail = id,
      insertText = item,
      textEdit = {
        newText = item,
        range = {
          start = { line = context.cursor[1] - 1, character = context.bounds.start_col - 1 },
          ["end"] = { line = context.cursor[1] - 1, character = context.bounds.end_col },
        },
      },
      source_id = self._config.name:lower(),
      source_name = self._config.name,
      cursor_column = context.cursor[2],
      score_offset = 0,
    }
  end
  function source:get_completions(context, callback)
    cleanup_caches(self)
    local input = context:get_keyword()
    require("ai.utils").debug("get_completions: input = " .. input, { title = "NvimAI Completion" })
    if self.cache[input] then
      require("ai.utils").debug("get_completions: cache hit for " .. input, { title = "NvimAI Completion" })
      return callback({
        is_incomplete_forward = false,
        is_incomplete_backward = false,
        items = self.cache[input],
        is_cached = true,
      })
    end
    local ok, items = pcall(function()
      local results = {}
      for id, command in pairs(self._commands) do
        if input:match("^" .. vim.pesc(command.label)) then
          require("ai.utils").debug("get_completions: command match " .. command.label, { title = "NvimAI Completion" })
          table.insert(results, create_completion_item(command, context))
        end
      end
      for id, fn in pairs(self._dynamic_completions) do
        if input:match("^" .. vim.pesc(id)) then
          require("ai.utils").debug("get_completions: dynamic match " .. id, { title = "NvimAI Completion" })
          local dynamic_items = fn(context)
          for _, item in ipairs(dynamic_items) do
            table.insert(results, create_dynamic_completion_item(item, context, id))
          end
        end
      end
      return results
    end)
    if not ok then
      require("ai.events").emit("completion_error", {
        source = self._config.name:lower(),
        error = items,
      })
      return callback({
        is_incomplete_forward = false,
        is_incomplete_backward = false,
        items = {},
      })
    end
    self.cache[input] = items
    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = items,
    })
  end
  function source:resolve(item, callback)
    if self.resolved_cache[item.label] then
      return callback(self.resolved_cache[item.label])
    end
    vim.schedule(function()
      local ok, resolved_item = pcall(function()
        local resolved = vim.deepcopy(item)
        -- Add any additional resolution logic here
        return resolved
      end)
      if not ok then
        require("ai.events").emit("completion_error", {
          source = self._config.name:lower(),
          error = resolved_item,
        })
        return callback(item)
      end
      self.resolved_cache[item.label] = resolved_item
      callback(resolved_item)
    end)
  end
  function source:execute(context, item, callback)
    vim.schedule(function()
      local ok, err = pcall(function()
        for id, command in pairs(self._commands) do
          if item.label == command.label then
            require("ai.events").emit("completion_mode_change", {
              mode = id,
              trigger = item.label,
            })
            break
          end
        end
      end)
      if not ok then
        require("ai.events").emit("completion_error", {
          source = self._config.name:lower(),
          error = err,
        })
      end
      callback()
    end)
  end
  return source
end
return SourceBuilder
