--- Command definitions for completion functionality
--- @class AI.CompletionCommands
local Commands = {}
local Events = require("ai.events")
local Config = require("ai.config")

function Commands.setup()
  vim.api.nvim_create_user_command("DebugNvimAICompletion", Commands._debug_completion, {
    desc = "Debug NvimAI completion configuration and status",
  })
end

function Commands._debug_completion()
  -- Validate context
  if vim.bo.filetype ~= Config.FILE_TYPE then
    Events.emit("debug_command_error", {
      reason = "wrong_filetype",
      expected = Config.FILE_TYPE,
      got = vim.bo.filetype,
    })
    vim.notify("This command only works in chat-dialog buffers", vim.log.levels.WARN)
    return
  end

  -- Collect debug info
  local source = require("ai.completion.source").new()
  local current_config = require("ai.completion.config").get()

  local debug_info = {
    providers = current_config.sources.providers,
    filetype = vim.bo.filetype,
    expected_filetype = Config.FILE_TYPE,
    source_available = source:is_available(),
    cache_stats = {
      items_cached = vim.tbl_count(source.cache or {}),
      resolved_cached = vim.tbl_count(source.resolved_cache or {}),
    },
    config = vim.inspect(current_config),
  }

  Events.emit("debug_info_collected", { info = debug_info })

  -- Print debug info
  for key, value in pairs(debug_info) do
    print(string.format("%s: %s", key, vim.inspect(value)))
  end
end

return Commands
