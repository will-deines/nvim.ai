--- Source definitions and configuration
--- @class AI.CompletionSources
local Sources = {}

Sources.default = {
  -- Source selection logic
  default = function(ctx)
    if not ctx or not ctx.bufnr then
      return {}
    end
    local ft = vim.bo[ctx.bufnr].filetype
    if ft == "chat-dialog" then
      return { "nvimai", "path", "buffer" }
    end
    return {}
  end,

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
        -- Additional transformations if needed
        return items
      end,
      should_show_items = true,
      max_items = 200,
      min_keyword_length = 1,
      fallbacks = {},
      score_offset = 0,
    },
    path = require("ai.completion.providers.path"),
    buffer = require("ai.completion.providers.buffer"),
  },
}
