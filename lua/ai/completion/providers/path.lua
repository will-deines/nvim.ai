return {
  name = "Path",
  module = "blink.cmp.sources.path",
  enabled = function(ctx)
    -- Only enable for /file commands
    local line = ctx.line:sub(1, ctx.cursor[2])
    return line:match("^/file%s+") ~= nil
  end,
  min_keyword_length = function(ctx)
    return 0 -- Allow completion immediately after /file
  end,
  transform_items = function(ctx, items)
    -- Adjust ranges to account for "/file " prefix
    for _, item in ipairs(items) do
      if item.textEdit then
        local prefix_len = #"/file "
        item.textEdit.range.start.character = prefix_len
        item.textEdit.range["end"].character = prefix_len
          + (item.textEdit.range["end"].character - item.textEdit.range.start.character)
      end
    end
    return items
  end,
  -- ... rest of config
}
