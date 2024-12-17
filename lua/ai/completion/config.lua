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
          if not ctx then
            return false
          end
          local is_enabled = vim.bo[ctx.bufnr or 0].filetype == "chat-dialog"
          require("ai.utils").debug(
            "Completion source enabled check: " .. tostring(is_enabled),
            { title = "NvimAI Completion" }
          )
          return is_enabled
        end,
      },
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
