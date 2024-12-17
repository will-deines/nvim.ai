--- Configuration management for completion functionality
--- @class AI.CompletionConfig
local Config = {}
local defaults = {
  sources = {
    default = { "nvimai" },
    providers = {
      nvimai = function()
        local source = require("ai.completion.cmp_source")
        require("ai.utils").debug("Loading completion source: NvimAI", { title = "NvimAI Completion" })
        return source
      end,
    },
  },
}
local config = vim.deepcopy(defaults)
function Config.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
  -- Add a dummy module key to each provider
  for name, provider in pairs(config.sources.providers) do
    if type(provider) == "function" then
      config.sources.providers[name] = function()
        local source = provider()
        source.module = "dummy"
        return source
      end
    end
  end
end
function Config.get()
  return config
end
return Config
