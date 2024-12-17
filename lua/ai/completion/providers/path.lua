return {
  name = "Path",
  module = "blink.cmp.sources.path",
  score_offset = function()
    return 3
  end,
  opts = {
    get_cwd = function(ctx)
      return vim.fn.getcwd()
    end,
    trailing_slash = true,
    label_trailing_slash = true,
  },
  -- Add this configuration
  min_keyword_length = function(ctx)
    -- Only trigger after "/file "
    local line = ctx.line:sub(1, ctx.cursor[2])
    return line:match("^/file%s+") and 0 or 999
  end,
  transform_items = function(ctx, items)
    -- Adjust the textEdit ranges to account for "/file " prefix
    for _, item in ipairs(items) do
      if item.textEdit then
        local prefix_len = #"/file "
        item.textEdit.range.start.character = item.textEdit.range.start.character + prefix_len
        item.textEdit.range["end"].character = item.textEdit.range["end"].character + prefix_len
      end
    end
    return items
  end,
}
