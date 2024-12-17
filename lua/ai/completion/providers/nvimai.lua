--- NvimAI completion provider configuration
return {
  name = "NvimAI",
  module = "ai.completion.source",

  enabled = function(ctx)
    local is_enabled = vim.bo[ctx.bufnr].filetype == "chat-dialog"
    require("ai.events").emit("provider_status", {
      name = "nvimai",
      enabled = is_enabled,
      context = ctx,
    })
    return is_enabled
  end,

  transform_items = function(ctx, items)
    require("ai.events").emit("provider_transform", {
      name = "nvimai",
      items_count = #items,
    })
    return items
  end,

  should_show_items = function()
    return true
  end,
  max_items = function()
    return 200
  end,
  min_keyword_length = function()
    return 1
  end,
  fallbacks = function()
    return {}
  end,
  score_offset = function()
    return 0
  end,

  opts = {
    completion = {
      keyword_pattern = [[\%(/[a-zA-Z]*\)]],
      trigger = {
        characters = { "/" },
        show_on_keyword = true,
        show_on_trigger_character = true,
      },
    },
  },
}
