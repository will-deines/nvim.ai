
# 🤖 Garrio Internal NVIM AI Assistant
>
> 🔒 Internal Neovim plugin for AI-assisted coding at Garrio, forked from [nvim.ai](https://github.com/magicalne/nvim.ai)

## ✨ Features

- 🗣️ **Multi-Provider Support**
  - OpenAI GPT-4, o1
  - Anthropic Claude
  - Google Gemini
  - Groq
  - Cohere
  - DeepSeek
  - Local models (Ollama, Kobold)
- 💬 **Interactive Chat Dialog**
  - Hideable Floating window interface
  - Code-aware conversations
  - Context-sensitive completions
  - Markdown rendering
  - Syntax highlighting
- 🧠 **Context-Aware Assistance**
  - Smart code explanations
  - Code review suggestions
  - Project-wide awareness
  - Multi-file context

## 🛠️ Internal Installation

```lua
-- In your Neovim config:
{
    "garrio/nvim-ai",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    config = function()
        require("ai").setup({
            provider = "anthropic", -- Configure your preferred provider
        })
    end
}
```

## ⚙️ Configuration

```lua
require("ai").setup({
    provider = "anthropic", -- Default provider
    ui = {
        width = 80,
        side = "right",
    },
    keymaps = {
        toggle = "<leader>1",
        select_model = "<leader>2",
        send = "<CR>",
        close = "q",
        clear = "<C-l>",
    },
    -- File completion configuration
    file_completion = {
        exclude_patterns = {
            "*.git/*",
            "*/node_modules/*",
            "*/target/*",
            "*/dist/*",
            "*.pyc",
            "*.venv*"
        },
        max_files = 1000,
        max_chars = 50000,
        show_directories_first = true,
        respect_gitignore = true
    }
})
```

### File Exclusion Patterns

The plugin automatically excludes certain paths and files from being included in the context to avoid overwhelming the AI with irrelevant information:

- `*.git/*` - Git repository metadata
- `*/node_modules/*` - Node.js dependencies
- `*/target/*` - Build outputs
- `*/dist/*` - Distribution files
- `*.pyc` - Python bytecode
- `*.venv*` - Python virtual environments

You can customize these patterns in the configuration to match your project structure.

### Default Behaviors

- Maximum of 1000 files scanned per directory
- Maximum of 50,000 characters per file
- Directories shown first in completions
- Respects `.gitignore` patterns
- Files are cached to improve performance

```

## 🔑 Environment Setup

Add to your `.zshrc`, `.bashrc` or equivalent:

```bash
export ANTHROPIC_API_KEY=""
export CO_API_KEY=""
export GROQ_API_KEY=""
export DEEPSEEK_API_KEY=""
```

## 💬 Advanced Chat Usage

### Chat Window Features

The chat dialog is a powerful interface that supports iterative development and context-aware conversations:

#### Document Management

- 📄 **Add Documents**: Reference any file or buffer

  ``` text
  /buf 1    # Reference current buffer
  /file path/to/file.js
  /dir src/components/
  ```

- 💾 **Document Caching**: Documents are cached to reduce API costs and improve response times
- 🔄 **Context Preservation**: Chat history maintains full context of your conversation
- 🔄 **History Saved**: Review prior conversations saved at each window clear.

#### Interactive Editing

- ✏️ **Edit Previous Messages**: Modify any previous message to refine the AI's understanding
- 🔄 **Iterative Refinement**: Edit your last prompt if you don't like the response
- 📝 **Multi-Message Context**: Build complex conversations with multiple code references

#### Chat Structure

The chat uses special commands to organize conversation:

``` text
/system You are an expert in React and TypeScript
/user
How can I improve this component's performance?
/assistant
[AI response appears here...]
/user
Could you also check if these utility functions are optimal?
```

#### Pro Tips

- 🎯 Edit the system prompt anytime to redirect the AI's expertise
- 📚 Add multiple files/buffers in a single message for comprehensive context
- ⚡ Use `/model` command to switch between different AI models mid-conversation
- 🔍 Previous chats are automatically saved and can be referenced later
- ♻️ Clear chat history with `Ctrl-l` to start fresh

## 🎯 Quick Commands

- `<leader>1` - Toggle chat
- `q` - Close chat
- `Enter` - Send message
- `Ctrl-l` - Clear history
- `<leader>2` - Select provider/model

## 📝 License

Internal Garrio use only. Forked from [nvim.ai](https://github.com/magicalne/nvim.ai) under Apache License.

---
🔒 **Note**: This is an internal tool for Garrio employees only. Not open for external contributions.
