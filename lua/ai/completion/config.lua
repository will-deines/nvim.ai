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
    keyword = {
      range = "prefix",
      regex = "[-_]\\|\\k",
      exclude_from_prefix_regex = "-",
    },
    trigger = {
      show_on_keyword = true,
      show_on_trigger_character = true,
      show_on_blocked_trigger_characters = { " ", "\n", "\t" },
      show_on_accept_on_trigger_character = true,
      show_on_insert_on_trigger_character = true,
    },
    list = {
      max_items = 200,
      selection = "preselect",
      cycle = {
        from_bottom = true,
        from_top = true,
      },
    },
    accept = {
      create_undo_point = true,
      auto_brackets = {
        enabled = true,
        default_brackets = { "(", ")" },
        override_brackets_for_filetypes = {},
        force_allow_filetypes = {},
        blocked_filetypes = {},
        kind_resolution = {
          enabled = true,
          blocked_filetypes = { "typescriptreact", "javascriptreact", "vue" },
        },
        semantic_token_resolution = {
          enabled = true,
          blocked_filetypes = {},
          timeout_ms = 400,
        },
      },
    },
    menu = {
      enabled = true,
      min_width = 15,
      max_height = 10,
      border = "none",
      winblend = 0,
      winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
      scrolloff = 2,
      scrollbar = true,
      direction_priority = { "s", "n" },
      auto_show = true,
      cmdline_position = function()
        if vim.g.ui_cmdline_pos ~= nil then
          local pos = vim.g.ui_cmdline_pos -- (1, 0)-indexed
          return { pos[1] - 1, pos[2] }
        end
        local height = (vim.o.cmdheight == 0) and 1 or vim.o.cmdheight
        return { vim.o.lines - height, 0 }
      end,
    },
    documentation = {
      auto_show = false,
      auto_show_delay_ms = 500,
      update_delay_ms = 50,
      treesitter_highlighting = true,
      window = {
        min_width = 10,
        max_width = 60,
        max_height = 20,
        desired_min_width = 50,
        desired_min_height = 10,
        border = "padded",
        winblend = 0,
        winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder",
        scrollbar = true,
        direction_priority = {
          menu_north = { "e", "w", "n", "s" },
          menu_south = { "e", "w", "s", "n" },
        },
      },
    },
    ghost_text = {
      enabled = false,
    },
  },

  -- Source configuration
  sources = require("ai.completion.sources").default,

  -- Appearance
  appearance = {
    highlight_ns = vim.api.nvim_create_namespace("blink_cmp"),
    use_nvim_cmp_as_default = false,
    nerd_font_variant = "mono",
    kind_icons = {
      Text = "󰉿",
      Method = "󰊕",
      Function = "󰊕",
      Constructor = "󰒓",
      Field = "󰜢",
      Variable = "󰆦",
      Property = "󰖷",
      Class = "󱡠",
      Interface = "󱡠",
      Struct = "󱡠",
      Module = "󰅩",
      Unit = "󰪚",
      Value = "󰦨",
      Enum = "󰦨",
      EnumMember = "󰦨",
      Keyword = "󰻾",
      Constant = "󰏿",
      Snippet = "󱄽",
      Color = "󰏘",
      File = "󰈔",
      Reference = "󰬲",
      Folder = "󰉋",
      Event = "󱐋",
      Operator = "󰪚",
      TypeParameter = "󰬛",
    },
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
