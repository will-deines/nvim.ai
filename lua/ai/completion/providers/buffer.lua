--- Buffer completion provider configuration
return {
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
}
