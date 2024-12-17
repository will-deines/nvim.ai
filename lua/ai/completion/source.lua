--- Completion source definition and management
--- @class AI.CompletionSource
local Source = {}
Source.__index = Source
--- Create a new completion source
--- @param name string The name of the source
--- @return AI.CompletionSource The new source object
function Source.new(name)
  local self = setmetatable({
    name = name,
    cache = {},
    resolved_cache = {},
    MAX_CACHE_SIZE = 1000,
  }, Source)
  return self
end
--- Check if the source is available
--- @return boolean True if the source is available, false otherwise
function Source:is_available()
  return true
end
--- Get completion items for the given context
--- @param context table The completion context
--- @param callback fun(items: table) The callback function to call with the completion items
function Source:get_completions(context, callback)
  local input = context:get_keyword()
  if self.cache[input] then
    require("ai.events").emit("cache_hit", { source = self.name, input = input })
    return callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = self.cache[input],
    })
  end
  require("ai.events").emit("cache_miss", { source = self.name, input = input })
  local items = {}
  for id, command in pairs(self._commands) do
    if input:match("^" .. vim.pesc(command.label)) then
      table.insert(items, {
        label = command.label,
        kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        detail = command.detail,
        documentation = { kind = "markdown", value = command.doc },
        insertText = command.label,
        textEdit = {
          newText = command.label,
          range = {
            start = { line = context.cursor[1] - 1, character = context.bounds.start_col - 1 },
            ["end"] = { line = context.cursor[1] - 1, character = context.bounds.end_col },
          },
        },
      })
    end
  end
  self.cache[input] = items
  callback({
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items,
  })
end
--- Resolve a completion item
--- @param item table The completion item to resolve
--- @param callback fun(resolved_item: table) The callback function to call with the resolved item
function Source:resolve(item, callback)
  if self.resolved_cache[item.label] then
    return callback(self.resolved_cache[item.label])
  end
  vim.schedule(function()
    local resolved = vim.deepcopy(item)
    -- Add any additional resolution logic here
    self.resolved_cache[item.label] = resolved
    callback(resolved)
  end)
end
--- Execute a completion item
--- @param context table The completion context
--- @param item table The completion item to execute
--- @param callback fun() The callback function to call after execution
function Source:execute(context, item, callback)
  vim.schedule(function()
    for id, command in pairs(self._commands) do
      if item.label == command.label then
        require("ai.events").emit("completion_mode_change", {
          mode = id,
          trigger = item.label,
        })
        break
      end
    end
    callback()
  end)
end
return Source
