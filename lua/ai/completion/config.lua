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
    -- ... (keep all the completion config from before)
  },
  -- Source configuration
  sources = {
    -- Source selection logic
    default = { "path", "buffer", "nvimai" },
    -- Provider definitions
    providers = {
      nvimai = {
        name = "NvimAI",
        module = "ai.completion.cmp_source", -- Point to our source file
        enabled = function(ctx)
          return vim.bo[ctx.bufnr].filetype == "chat-dialog"
        end,
        async = false,
        timeout_ms = 1000,
        transform_items = function(ctx, items)
          return items
        end,
        should_show_items = true,
        max_items = 200,
        min_keyword_length = 1,
        fallbacks = {},
        score_offset = 0,
      },
      path = {
        name = "Path",
        module = "blink.cmp.sources.path",
        enabled = true,
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
        opts = {
          completion = {
            keyword_pattern = [[\%(\/buf\s\+\)\zs[^[:space:]*]],
            trigger = {
              characters = { "/", " " },
              show_on_keyword = true,
              show_on_trigger_character = true,
            },
          },
        },
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
