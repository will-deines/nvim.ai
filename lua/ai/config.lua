local M = {}

M.BASE_PROVIDER_KEYS =
  { "endpoint", "models", "local", "deployment", "api_version", "proxy", "allow_insecure", "max_tokens", "stream" }
M.FILE_TYPE = "chat-dialog"

-- Add this near the top of the file, after the local M = {} line
local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Default configuration
M.defaults = {
  file_completion = {
    exclude_patterns = {
      "*.git/*",
      "*/node_modules/*",
      "*/target/*",
      "*/dist/*",
      "*.pyc",
      "*.venv*",
    },
    max_files = 1000,
    max_chars = 50000,
    show_directories_first = true,
    respect_gitignore = true,
  },

  debug = true,
  -- Chat Dialog UI configuration
  ui = {
    width = 80, -- Width of the chat dialog window
    side = "right", -- Side of the editor to open the dialog ('left' or 'right')
    borderchars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    highlight = {
      border = "FloatBorder", -- Highlight group for the border
      background = "NormalFloat", -- Highlight group for the background
    },
    prompt_prefix = "❯ ", -- Prefix for the input prompt
  },

  -- LLM configuration
  provider = "openai",
  model = "gpt-4o",
  deepseek = {
    endpoint = "https://api.deepseek.com",
    models = { "deepseek-chat" },
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  cohere = {
    endpoint = "https://api.cohere.com",
    models = { "command-r-plus", "command-r" },
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  groq = {
    endpoint = "https://api.groq.com",
    models = { "llama-3.1-70b-versatile" },
    temperature = 0,
    max_tokens = 4096,
    ["local"] = false,
  },
  anthropic = {
    endpoint = "https://api.anthropic.com",
    models = { "claude-3-5-sonnet-latest", "claude-3-5-haiku-latest" },
    temperature = 0.1,
    max_tokens = {
      ["claude-3-5-sonnet-latest"] = 8192,
      ["claude-3-5-haiku-latest"] = 8192,
    },
    stream = false,
    ["local"] = false,
  },
  openai = {
    endpoint = "https://api.openai.com",
    models = { "gpt-4o", "gpt-4o-mini" },
    temperature = 0.1,
    max_tokens = {
      ["gpt-4o"] = 4096,
      ["gpt-4o-mini"] = 4096,
    },
    stream = false,
    ["local"] = false,
  },
  openaioseries = {
    endpoint = "https://api.openai.com",
    models = { "o1-mini", "o1-preview", "o1" },
    temperature = 1,
    max_tokens = {
      ["o1-mini"] = 65500,
      ["o1-preview"] = 32768,
      ["o1"] = 32768,
    },
    stream = false,
    ["local"] = false,
  },
  gemini = {
    endpoint = "https://generativelanguage.googleapis.com",
    models = {
      "gemini-1.5-pro-latest",
      "gemini-1.5-flash-latest",
      "gemini-2.0-flash-exp",
    },
    generationConfig = {
      maxOutputTokens = 8192,
      temperature = 0.1,
      topP = 1.0,
      topK = 40,
    },
    safetySettings = {
      -- Optional safety settings as per API docs
      -- HARM_CATEGORY_HARASSMENT = "BLOCK_NONE",
      -- HARM_CATEGORY_HATE_SPEECH = "BLOCK_NONE",
      -- HARM_CATEGORY_SEXUALLY_EXPLICIT = "BLOCK_NONE",
      -- HARM_CATEGORY_DANGEROUS_CONTENT = "BLOCK_NONE"
    },
    stream = false,
    ["local"] = false,
  },
  kobold = {
    endpoint = "http://localhost:5001",
    max_context_length = 131072,
    max_length = 131072,
    temperature = 0.1,
    top_p = 0.9,
    top_k = 100,
    rep_pen = 1.1,
    rep_pen_range = 256,
    rep_pen_slope = 1,
    ["local"] = true,
  },

  ollama = {
    endpoint = "http://localhost:11434",
    model = "gemma2",
    temperature = 0,
    max_tokens = 4096,
    ["local"] = true,
  },

  vendors = {},

  saved_chats_dir = vim.fn.stdpath("data") .. "/nvim.ai/saved_chats",

  -- Keymaps
  keymaps = {
    toggle = "<leader>1", -- Toggle chat dialog
    select_model = "<leader>2", -- Change the provider & model
    send = "<CR>", -- Send message in normal mode
    close = "q", -- Close chat dialog
    clear = "<C-l>", -- Clear chat history
  },

  -- Behavior
  behavior = {
    auto_open = true, -- Automatically open dialog when sending a message
    save_history = true, -- Save chat history between sessions
    history_dir = vim.fn.stdpath("data"), -- Path to save chat history
  },

  -- TODO: Appearance
  appearance = {
    icons = {
      user = "🧑", -- Icon for user messages
      assistant = "🤖", -- Icon for assistant messages
      system = "🖥️", -- Icon for system messages
      error = "❌", -- Icon for error messages
    },
    syntax_highlight = true, -- Syntax highlight code in responses
  },
}

M.has_provider = function(provider)
  return M.config[provider] ~= nil or M.vendors[provider] ~= nil
end

M.get_provider = function(provider)
  if M.config[provider] ~= nil then
    return vim.deepcopy(M.config[provider], true)
  elseif M.config.vendors[provider] ~= nil then
    return vim.deepcopy(M.config.vendors[provider], true)
  else
    error("Failed to find provider: " .. provider, 2)
  end
end

-- Function to merge user config with defaults
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.defaults, user_config or {})

  -- Validate configuration
  assert(M.config.ui.side == "left" or M.config.ui.side == "right", "UI side must be 'left' or 'right'")
  assert(type(M.config.ui.width) == "number", "UI width must be a number")

  -- Set up API key
  -- if not M.config.llm.api_key then
  --   local env_var = M.config.llm.provider == "openai" and "OPENAI_API_KEY" or "ANTHROPIC_API_KEY"
  --   M.config.llm.api_key = vim.env[env_var]
  --   assert(M.config.llm.api_key, env_var .. " environment variable not set")
  -- end
end

function M.get(what)
  return M.config[what]
end

return M
