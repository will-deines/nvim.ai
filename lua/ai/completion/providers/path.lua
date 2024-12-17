return {
  name = "Path",
  module = "blink.cmp.sources.path",
  score_offset = function()
    return 3
  end,
  opts = {
    -- These options should be passed directly to the path source
    get_cwd = function(ctx)
      return vim.fn.expand(("#%d:p:h"):format(ctx.bufnr))
    end,
    trailing_slash = true,
    label_trailing_slash = true,
  },
}
