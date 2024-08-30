local config = require("ai.config")
local Assistant = require("ai.assistant")
local api = vim.api
local message_handler = require("ai.chat-dialog-handlers.message_handler")
local code_block_navigator = require("ai.chat-dialog-handlers.code_block_navigator")

local ChatDialog = {}
ChatDialog.config = {
  width = 40,
  side = "right",
  borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
}

local state = {
  buf = nil,
  win = nil,
  last_saved_file = nil,
}

local function create_buf()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "bufhidden", "hide")
  api.nvim_buf_set_option(buf, "buflisted", false)
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_option(buf, "filetype", config.FILE_TYPE)
  return buf
end

local function get_win_config()
  local width = ChatDialog.config.width
  local height = api.nvim_get_option("lines") - 4
  local col = ChatDialog.config.side == "left" and 0 or (api.nvim_get_option("columns") - width)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = 0,
    col = col,
    style = "minimal",
    border = ChatDialog.config.borderchars,
  }
end

local function get_project_name()
  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ":t")
end

local function generate_chat_filename()
  local project_name = get_project_name()
  local save_dir = config.config.saved_chats_dir .. "/" .. project_name
  -- Create the directory if it doesn't exist
  vim.fn.mkdir(save_dir, "p")
  -- Generate a unique filename based on timestamp
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = save_dir .. "/chat_" .. timestamp .. ".md"
  return filename
end

function ChatDialog.save_file()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    print("No valid chat buffer to save.")
    return
  end
  local filename = state.last_saved_file or generate_chat_filename()
  -- Get buffer contents
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  -- Write to file
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    print("Chat saved to: " .. filename)
    -- Set the buffer name to the saved file path
    api.nvim_buf_set_name(state.buf, filename)
    -- Update the last saved file
    state.last_saved_file = filename
  else
    print("Failed to save chat to file: " .. filename)
  end
end

local function find_most_recent_chat_file()
  local project_name = get_project_name()
  local save_dir = config.config.saved_chats_dir .. "/" .. project_name
  local files = vim.fn.glob(save_dir .. "/chat_*.md", 0, 1)
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  if state.last_saved_file == nil then
    state.last_saved_file = files[1]
  end
  return files[1] -- Return the most recent file, or nil if no files found
end

function ChatDialog.open()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    return
  end
  local file_to_load = state.last_saved_file or find_most_recent_chat_file()
  if file_to_load then
    state.buf = vim.fn.bufadd(file_to_load)
    vim.fn.bufload(state.buf)
    api.nvim_buf_set_option(state.buf, "buftype", "nofile")
    api.nvim_buf_set_option(state.buf, "bufhidden", "hide")
    api.nvim_buf_set_option(state.buf, "swapfile", false)
    api.nvim_buf_set_option(state.buf, "filetype", config.FILE_TYPE)
  else
    state.buf = state.buf or create_buf()
  end
  local win_config = get_win_config()
  state.win = api.nvim_open_win(state.buf, true, win_config)
  -- Set window options
  api.nvim_win_set_option(state.win, "wrap", true)
  api.nvim_win_set_option(state.win, "linebreak", true) -- Wrap at word boundaries
  api.nvim_win_set_option(state.win, "cursorline", true)
  -- Check if the buffer is empty and add "/you:" followed by two line breaks if it is
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    api.nvim_buf_set_lines(state.buf, 0, -1, false, { "/you:", "", "" })
    -- Set the cursor to the end of the two newlines after "/you:"
    api.nvim_win_set_cursor(state.win, { 3, 0 })
  end
  -- Focus on the chat dialog window
  api.nvim_set_current_win(state.win)
  -- Automatically enter insert mode
  vim.cmd("startinsert")
end

function ChatDialog.close()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function ChatDialog.toggle()
  if state.win and api.nvim_win_is_valid(state.win) then
    ChatDialog.close()
  else
    ChatDialog.open()
  end
end

function ChatDialog.on_complete(t)
  message_handler.append_text(state, "\n\n/you:\n")
  vim.schedule(function()
    ChatDialog.save_file()
  end)
end

-- Add a function to parse and store the model from the /model command
local function parse_model_command(line)
  local model = line:match("^/model%s+(.+)")
  if model then
    state.current_model = model
    print("Model set to: " .. model)
  end
end

function ChatDialog.send()
  local system_prompt = message_handler.get_system_prompt(state)
  local chat_history = message_handler.get_chat_history(state)
  local last_user_request = message_handler.last_user_request(state)
  local full_prompt = chat_history .. "\n/you:\n" .. last_user_request

  -- Check for /model command in the last user request
  parse_model_command(last_user_request)

  message_handler.append_text(state, "\n\n/assistant:\n")
  Assistant.ask(system_prompt, full_prompt, function(response)
    message_handler.append_text(state, response)
  end, function()
    ChatDialog.on_complete()
  end, state.current_model) -- Pass the current model to the ask function
end

function ChatDialog.clear()
  if state.buf and api.nvim_buf_is_valid(state.buf) then
    api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
  end
end

function ChatDialog.setup()
  ChatDialog.config = vim.tbl_deep_extend("force", ChatDialog.config, config.config.ui or {})
  -- Create user commands
  api.nvim_create_user_command("ChatDialogToggle", function()
    ChatDialog.toggle()
  end, {})
  api.nvim_create_user_command("ChatDialogClear", function()
    ChatDialog.clear()
  end, {})
end

return ChatDialog
