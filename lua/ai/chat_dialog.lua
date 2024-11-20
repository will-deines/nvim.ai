local config = require("ai.config")
local Assistant = require("ai.assistant")
local api = vim.api
local message_handler = require("ai.chat-dialog-handlers.message_handler")
local utils = require("ai.utils")
local providers = require("ai.providers")
local fzf = require("fzf-lua")

local ChatDialog = {}
ChatDialog.config = {
  width = 40,
  side = "right",
  borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
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

local function selectProvider(callback)
  -- Directly use M.default_providers to ensure the data is correctly passed
  local provider_list = providers.default_providers
  if not provider_list or #provider_list == 0 then
    print("No providers available.")
    return
  end

  fzf.fzf_exec(provider_list, {
    prompt = "Select a Provider> ",
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          callback(selected[1])
          utils.state.selectedProvider = selected[1]
        end
      end,
    },
  })
end

local function selectModel(provider, callback)
  -- Safely get the provider configuration using M.get_provider
  local success, providerConfig = pcall(config.get_provider, provider)
  if not success or not providerConfig then
    print("Provider not found in config.")
    return
  end

  -- Ensure the provider has the `models` key
  local models = providerConfig.models
  if not models or #models == 0 then
    print("No models available for the selected provider.")
    return
  end

  -- Proceed with the FZF selection if models exist
  fzf.fzf_exec(models, {
    prompt = "Select a Model> ",
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          callback(selected[1])
          utils.state.selectedModel = selected[1] -- Store selected model
        end
      end,
    },
  })
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
  if not (utils.state.buf and api.nvim_buf_is_valid(utils.state.buf)) then
    print("No valid chat buffer to save.")
    return
  end
  local filename = utils.state.last_saved_file or generate_chat_filename()
  -- Get buffer contents
  local lines = api.nvim_buf_get_lines(utils.state.buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  -- Write to file
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    print("Chat saved to: " .. filename)
    -- Set the buffer name to the saved file path
    api.nvim_buf_set_name(utils.state.buf, filename)
    -- Update the last saved file
    utils.state.last_saved_file = filename
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
  if utils.state.last_saved_file == nil then
    utils.state.last_saved_file = files[1]
  end
  return files[1] -- Return the most recent file, or nil if no files found
end

function ChatDialog.open()
  if utils.state.win and api.nvim_win_is_valid(utils.state.win) then
    api.nvim_set_current_win(utils.state.win)
    return
  end
  local file_to_load = utils.state.last_saved_file or find_most_recent_chat_file()
  if file_to_load then
    utils.state.buf = vim.fn.bufadd(file_to_load)
    vim.fn.bufload(utils.state.buf)
    api.nvim_buf_set_option(utils.state.buf, "buftype", "nofile")
    api.nvim_buf_set_option(utils.state.buf, "bufhidden", "hide")
    api.nvim_buf_set_option(utils.state.buf, "swapfile", false)
    api.nvim_buf_set_option(utils.state.buf, "filetype", config.FILE_TYPE)
  else
    utils.state.buf = utils.state.buf or create_buf()
  end
  local win_config = get_win_config()
  utils.state.win = api.nvim_open_win(utils.state.buf, true, win_config)
  -- Set window options
  api.nvim_win_set_option(utils.state.win, "wrap", true)
  api.nvim_win_set_option(utils.state.win, "linebreak", true) -- Wrap at word boundaries
  api.nvim_win_set_option(utils.state.win, "cursorline", true)
  -- Check if the buffer is empty and add "/user:" followed by two line breaks if it is
  local lines = api.nvim_buf_get_lines(utils.state.buf, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    api.nvim_buf_set_lines(utils.state.buf, 0, -1, false, { "/user:", "", "" })
    -- Set the cursor to the end of the two newlines after "/user:"
    api.nvim_win_set_cursor(utils.state.win, { 3, 0 })
  end
  -- Focus on the chat dialog window
  api.nvim_set_current_win(utils.state.win)
  -- Automatically enter insert mode
  -- vim.cmd("startinsert")
end

function ChatDialog.close()
  if utils.state.win and api.nvim_win_is_valid(utils.state.win) then
    api.nvim_win_close(utils.state.win, true)
  end
  utils.state.win = nil
end

function ChatDialog.toggle()
  if utils.state.win and api.nvim_win_is_valid(utils.state.win) then
    ChatDialog.close()
  else
    ChatDialog.open()
  end
end

function ChatDialog.on_complete(t)
  message_handler.append_text(utils.state, "\n\n/user:\n")
  vim.schedule(function()
    ChatDialog.save_file()
  end)
end

function ChatDialog.UpdateProviderAndModel(callback)
  selectProvider(function(selectedProvider)
    selectModel(selectedProvider, function(selectedModel)
      utils.state.current_model = selectedModel
      print("Provider and model updated.")
      if callback then
        callback()
      end
    end)
  end)
end

local function runChatProcess()
  local system_prompt = message_handler.get_system_prompt(utils.state)
  local chat_history = message_handler.get_chat_history(utils.state)
  local last_user_request = message_handler.last_user_request(utils.state)
  local full_prompt = chat_history .. "\n/user:\n" .. last_user_request

  message_handler.append_text(utils.state, "\n\n/assistant:\n")
  Assistant.ask(system_prompt, full_prompt, function(response)
    message_handler.append_text(utils.state, response)
  end, function()
    ChatDialog.on_complete()
  end)
end

function ChatDialog.send()
  if not utils.state.selectedProvider and not utils.state.current_model then
    -- Call updateProviderAndModel and pass runChatProcess as a callback
    ChatDialog.UpdateProviderAndModel(runChatProcess)
  else
    -- Run the chat process directly
    runChatProcess()
  end
end

-- Store and archive chat history file
function ChatDialog.save_and_create_new()
  if not (utils.state.buf and api.nvim_buf_is_valid(utils.state.buf)) then
    print("No valid chat buffer to save.")
    return
  end

  -- Get current buffer contents
  local lines = api.nvim_buf_get_lines(utils.state.buf, 0, -1, false)
  local expanded_content = message_handler.expand_commands_for_save(lines)

  -- Generate new filename and save expanded content
  local filename = generate_chat_filename()
  local file = io.open(filename, "w")
  if file then
    file:write(expanded_content)
    file:close()
    print("Chat saved to: " .. filename)
  else
    print("Failed to save chat to file: " .. filename)
    return
  end

  -- Create new empty buffer
  utils.state.buf = create_buf()
  if utils.state.win and api.nvim_win_is_valid(utils.state.win) then
    api.nvim_win_set_buf(utils.state.win, utils.state.buf)
    api.nvim_buf_set_lines(utils.state.buf, 0, -1, false, { "/user:", "", "" })
    api.nvim_win_set_cursor(utils.state.win, { 3, 0 })
  end
end

-- Update the clear function
function ChatDialog.clear()
  if utils.state.buf and api.nvim_buf_is_valid(utils.state.buf) then
    ChatDialog.save_and_create_new()
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
