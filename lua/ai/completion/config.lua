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
end
function Config.get()
  return config
end
return Config
