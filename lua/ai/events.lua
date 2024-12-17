--- Event system for plugin coordination
--- @class AIEvents
--- @field private emitters table<string, fun(data: table)[]>
--- @field private registered_events string[]
local Events = {
  emitters = {},
  registered_events = {
    -- Plugin lifecycle
    "plugin_setup_start",
    "plugin_setup_complete",
    -- Component lifecycle
    "component_setup_start",
    "component_setup_success",
    "component_setup_failed",
    -- Command events
    "command_setup_failed",
    -- Provider events
    "provider_status",
    "provider_transform",
    -- Completion setup
    "completion_setup_start",
    "completion_setup_success",
    "completion_setup_failed",
    -- Completion lifecycle
    "completion_show",
    "completion_hide",
    "completion_accept",
    "completion_cancel",
    -- Completion testing
    "test_completion_start",
    "test_completion_end",
    -- Debug events
    "debug_log",
    "debug_completion",
    "debug_command_error",
    "debug_info_collected",
    -- Cache events
    "cache_clear",
    "cache_hit",
    "cache_miss",
    -- Error events
    "completion_error",
    -- Source events
    "source_register",
    "source_unregister",
    "source_reload",
    -- Keymap events
    "keymap_setup_start",
    "keymap_setup_complete",
    "keymap_error",
    -- Treesitter events
    "treesitter_error",
  },
}

--- Register an event handler
--- @param event string Event name or "*" for all events
--- @param callback fun(data: table) Handler function
function Events.on(event, callback)
  -- Handle wildcard subscription
  if event == "*" then
    for _, registered_event in ipairs(Events.registered_events) do
      Events.on(registered_event, callback)
    end
    return
  end
  -- Validate event name
  if not vim.tbl_contains(Events.registered_events, event) then
    error(
      string.format("Invalid event name: %s. Valid events are: %s", event, table.concat(Events.registered_events, ", "))
    )
  end
  -- Initialize emitters table for this event
  Events.emitters[event] = Events.emitters[event] or {}
  table.insert(Events.emitters[event], callback)
end

--- Emit an event with optional data
--- @param event string
--- @param data? table
function Events.emit(event, data)
  -- Validate event name
  if not vim.tbl_contains(Events.registered_events, event) then
    error(
      string.format("Invalid event name: %s. Valid events are: %s", event, table.concat(Events.registered_events, ", "))
    )
  end

  -- Prepare event data
  data = data or {}
  data.timestamp = vim.fn.strftime("%Y-%m-%d %H:%M:%S")
  data.event = event

  -- Get handlers for this event
  local handlers = Events.emitters[event] or {}

  -- Schedule event emission to avoid blocking
  vim.schedule(function()
    -- Emit event to all registered handlers
    for _, callback in ipairs(handlers) do
      local ok, err = pcall(callback, data)
      if not ok then
        -- Log errors directly instead of emitting events
        vim.notify(string.format("Error in event handler for %s: %s", event, err), vim.log.levels.ERROR)
      end
    end

    -- Log debug info directly to vim.notify instead of emitting another event
    if vim.g.nvimai_debug then
      -- Use direct logging instead of event emission
      local debug_msg = string.format("[Event] %s", event)
      if type(data) == "table" then
        debug_msg = debug_msg .. ": " .. vim.inspect(data)
      end
      vim.notify(debug_msg, vim.log.levels.DEBUG)
    end
  end)
end

--- Remove an event handler
--- @param event string
--- @param callback fun(data: table)
function Events.off(event, callback)
  -- Validate event name
  if not vim.tbl_contains(Events.registered_events, event) then
    error(
      string.format("Invalid event name: %s. Valid events are: %s", event, table.concat(Events.registered_events, ", "))
    )
  end
  -- Get handlers for this event
  local handlers = Events.emitters[event] or {}
  -- Remove matching callback
  for i, registered_callback in ipairs(handlers) do
    if registered_callback == callback then
      table.remove(handlers, i)
      break
    end
  end
end

--- Clear all event handlers
function Events.clear()
  Events.emitters = {}
end

--- Register a new event type
--- @param event string
function Events.register(event)
  if not vim.tbl_contains(Events.registered_events, event) then
    table.insert(Events.registered_events, event)
  end
end

--- Setup debug logging
--- @param opts? {debug: boolean}
function Events.setup(opts)
  opts = opts or {}
  vim.g.nvimai_debug = opts.debug or false
end

return Events
