--- Configuration management for completion functionality
--- @class AI.CompletionConfig
local Config = {}

-- Default configuration
local defaults = {
  sources = {
    default = { "nvimai", "path", "buffer" },
    providers = {
      nvimai = {
        name = "NvimAI",
        module = "ai.completion.cmp_source",
        enabled = function(ctx)
          return vim.bo[ctx.bufnr].filetype == "chat-dialog"
        end,
      },
      path = {
        name = "Path",
        module = "blink.cmp.sources.path",
        enabled = function(ctx)
          -- Only enable for /file commands
          local line = ctx.line:sub(1, ctx.cursor[2])
          return line:match("^/file%s+") ~= nil
        end,
        opts = {
          get_cwd = function(ctx)
            return vim.fn.getcwd()
          end,
          trailing_slash = true,
          label_trailing_slash = true,
        },
      },
      buffer = {
        name = "Buffer",
        module = "blink.cmp.sources.buffer",
        enabled = function(ctx)
          -- Only enable for /buf commands
          local line = ctx.line:sub(1, ctx.cursor[2])
          return line:match("^/buf%s+") ~= nil
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
