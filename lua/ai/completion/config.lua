--- Configuration management for completion functionality
--- @class AI.CompletionConfig
local Config = {}

-- Default configuration
local defaults = {
  enabled = function()
    return true
  end,

  -- Core completion behavior
  completion = {
    keyword = require("blink.cmp.config.completion").default.keyword,
    trigger = {
      show_on_keyword = true,
      show_on_trigger_character = true,
      show_on_blocked_trigger_characters = { " ", "\n", "\t" },
      show_on_accept_on_trigger_character = true,
      show_on_insert_on_trigger_character = true,
    },
    list = require("blink.cmp.config.completion").default.list,
    accept = require("blink.cmp.config.completion").default.accept,
    menu = require("blink.cmp.config.completion").default.menu,
    documentation = require("blink.cmp.config.completion").default.documentation,
    ghost_text = require("blink.cmp.config.completion").default.ghost_text,
  },

  -- Source configuration
  sources = require("ai.completion.sources").default,

  -- Appearance
  appearance = require("blink.cmp.config.appearance").default,
}

local config = vim.deepcopy(defaults)

--- Setup completion configuration
--- @param opts table Configuration options
function Config.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
end

--- Get current configuration
--- @return table
function Config.get()
  return config
end

return Config
