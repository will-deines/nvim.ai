--- Component management and setup coordination
--- @class AI.Components
local Components = {}
local Events = require("ai.events")
-- Core component definitions
local core_components = {
  {
    name = "config",
    setup = function(opts)
      return require("ai.config").setup(opts)
    end,
  },
  {
    name = "chat_dialog",
    setup = function()
      return require("ai.chat_dialog").setup()
    end,
  },
  {
    name = "providers",
    setup = function()
      return require("ai.providers").setup()
    end,
  },
  {
    name = "completion",
    setup = function(opts)
      return require("ai.completion").setup(opts)
    end,
  },
  {
    name = "keymaps",
    setup = function()
      return require("ai.keymaps").setup()
    end,
  },
  {
    name = "commands",
    setup = function()
      return require("ai.commands").setup()
    end,
  },
}
--- Setup all plugin components
--- @param opts table Configuration options
--- @return { success: boolean, error?: string }
function Components.setup(opts)
  for _, component in ipairs(core_components) do
    Events.emit("component_setup_start", { component = component.name })
    local ok, err = pcall(component.setup, opts)
    if not ok then
      Events.emit("component_setup_failed", {
        component = component.name,
        error = err,
      })
      return {
        success = false,
        error = string.format("Failed to setup %s: %s", component.name, err),
      }
    end
    Events.emit("component_setup_success", { component = component.name })
  end
  return { success = true }
end
return Components
