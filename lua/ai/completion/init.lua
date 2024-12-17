--- Main completion setup and coordination module
--- @class AI.Completion
local Completion = {}
local Events = require("ai.events")
local Config = require("ai.completion.config")
local Commands = require("ai.completion.commands")

--- Setup completion functionality
--- @param opts table Plugin options
function Completion.setup(opts)
  Events.emit("completion_setup_start")

  -- Validate blink.cmp is available
  local ok, err = Completion._validate_dependencies()
  if not ok then
    Events.emit("completion_setup_failed", {
      reason = "missing_dependency",
      error = err,
    })
    return
  end

  -- Setup components
  local setup_result = Completion._setup_components(opts)
  if not setup_result.success then
    Events.emit("completion_setup_failed", setup_result)
    return
  end

  Events.emit("completion_setup_success")
end

function Completion._validate_dependencies()
  local plugin_config = require("lazy.core.config").plugins["blink.cmp"]
  if not plugin_config or not plugin_config.opts then
    return false, "blink.cmp config not found"
  end
  return true
end

function Completion._setup_components(opts)
  -- Setup completion config
  local ok, err = pcall(function()
    Config.setup(opts)
    Commands.setup()
    require("blink.cmp.config").merge_with(Config.get())
  end)

  if not ok then
    return {
      success = false,
      reason = "setup_failed",
      error = err,
    }
  end

  return { success = true }
end

return Completion
