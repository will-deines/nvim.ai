--- @class AIEvents
--- @field emitters table<string, fun(data: table)[]>
--- @field registered_events string[]
local Events = {
  emitters = {},
  registered_events = {
    -- Plugin lifecycle
    "plugin_setup_start",
    "plugin_setup_complete",

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

    -- Completion debugging
    "debug_completion",

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
  },
}

--- Register an event handler
--- @param event string
--- @param callback fun(data: table)
function Events.on(event, callback)
  -- Allow wildcard "*" event
  if event == "*" then
    -- Register callback for all events
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

  -- Add callback
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

  -- Get emitters for this event
  local event_emitters = Events.emitters[event] or {}

  -- Add timestamp and event name to data
  data = data or {}
  data.timestamp = vim.fn.strftime("%Y-%m-%d %H:%M:%S")
  data.event = event

  -- Schedule event emission to avoid blocking
  vim.schedule(function()
    -- Emit event to all registered handlers
    for _, callback in ipairs(event_emitters) do
      local ok, err = pcall(callback, data)
      if not ok then
        vim.notify(string.format("Error in event handler for %s: %s", event, err), vim.log.levels.ERROR)
      end
    end

    -- Log event if debug is enabled
    if vim.g.nvimai_debug then
      vim.notify(string.format("Event emitted: %s\nData: %s", event, vim.inspect(data)), vim.log.levels.DEBUG)
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

  -- Get emitters for this event
  local event_emitters = Events.emitters[event] or {}

  -- Remove callback
  for i, registered_callback in ipairs(event_emitters) do
    if registered_callback == callback then
      table.remove(event_emitters, i)
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

  -- Setup debug logging if enabled
  if vim.g.nvimai_debug then
    Events.on("*", function(data)
      -- Log to file
      local log_path = vim.fn.stdpath("cache") .. "/nvimai.log"
      local log = string.format("[%s] %s: %s\n", data.timestamp, data.event, vim.inspect(data))

      vim.fn.writefile({ log }, log_path, "a")
    end)
  end
end

return Events
