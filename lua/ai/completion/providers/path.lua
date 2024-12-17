return {
  name = "Path",
  module = "blink.cmp.sources.path",

  score_offset = function()
    return 3
  end,

  opts = {
    completion = {
      keyword_pattern = [[\%(\/file\s\+\|\/dir\s\+\)\zs[^[:space:]*]],
      trigger = {
        characters = { "/", " " },
        show_on_keyword = true,
        show_on_trigger_character = true,
      },
    },
  },
}
