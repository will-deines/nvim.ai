--- Main plugin initialization and coordination
--- @class AI
local AI = {}

local Events = require("ai.events")
local Components = require("ai.components")

--- Setup the plugin with provided options
--- @param opts table Configuration options
function AI.setup(opts)
  Events.emit("plugin_setup_start", { opts = opts })

  -- Setup events first since other components depend on it
  Events.setup({
    debug = opts.debug or false,
  })

  -- Setup core components
  local setup_result = Components.setup(opts)
  if not setup_result.success then
    vim.notify(string.format("Failed to setup AI plugin: %s", setup_result.error), vim.log.levels.ERROR)
    return
  end

  Events.emit("plugin_setup_complete")
end

return AI
