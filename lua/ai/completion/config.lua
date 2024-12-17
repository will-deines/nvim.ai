--- Configuration management for completion functionality
--- @class AI.CompletionConfig
local Config = {}

local defaults = {
  sources = {
    default = { "nvimai" },
    providers = {
      nvimai = {
        name = "NvimAI",
        module = "ai.completion.cmp_source",
        enabled = function(ctx)
          -- Add nil check
          if not ctx then
            return false
          end
          return vim.bo[ctx.bufnr or 0].filetype == "chat-dialog"
        end,
      },
    },
  },
  -- Appearance config
  appearance = {
    -- ... (keep all the appearance config from before)
  },
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
