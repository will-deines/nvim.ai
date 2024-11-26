local config = require("ai.config")
local Assistant = require("ai.assistant")
local api = vim.api
local message_handler = require("ai.chat-dialog-handlers.message_handler")
local utils = require("ai.utils")
local providers = require("ai.providers")
local fzf = require("fzf-lua")

local ChatDialog = {}

ChatDialog.config = {
  width = 80,
  side = "right",
  borderchars = {
    "─", -- top
    "│", -- right
    "─", -- bottom
    "│", -- left
    "╭", -- topleft
    "╮", -- topright
    "╯", -- botright
    "╰", -- botleft
  },
}

local function create_buf()
  local buf = api.nvim_create_buf(false, true)

  -- Set buffer options using vim.bo
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = config.FILE_TYPE

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
    row = 1, -- Added 1 to leave space for statusline
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

function ChatDialog.save_file(skip_rename)
  if not (utils.state.buf and api.nvim_buf_is_valid(utils.state.buf)) then
    print("No valid chat buffer to save.")
    return
  end

  local filename = utils.state.last_saved_file or generate_chat_filename()
  -- Get expanded buffer contents using get_chat_history
  local content = message_handler.get_chat_history(utils.state)

  -- Write to file
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    print("Chat saved to: " .. filename)

    -- Only set buffer name if not skipping rename
    if not skip_rename then
      api.nvim_buf_set_name(utils.state.buf, filename)
    end

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

    -- Set buffer options for loaded file
    vim.bo[utils.state.buf].buftype = "nofile"
    vim.bo[utils.state.buf].bufhidden = "hide"
    vim.bo[utils.state.buf].swapfile = false
    vim.bo[utils.state.buf].filetype = config.FILE_TYPE
  else
    utils.state.buf = utils.state.buf or create_buf()
  end

  local win_config = get_win_config()
  utils.state.win = api.nvim_open_win(utils.state.buf, true, win_config)

  -- Set window options using vim.wo
  vim.wo[utils.state.win].wrap = true
  vim.wo[utils.state.win].linebreak = true
  vim.wo[utils.state.win].cursorline = true

  -- Check if buffer is empty and initialize if needed
  local lines = api.nvim_buf_get_lines(utils.state.buf, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    api.nvim_buf_set_lines(utils.state.buf, 0, -1, false, { "/user:", "", "" })
    api.nvim_win_set_cursor(utils.state.win, { 3, 0 })
  end

  api.nvim_set_current_win(utils.state.win)
end

function ChatDialog.close()
  if utils.state.win and api.nvim_win_is_valid(utils.state.win) then
    utils.stop_loading() -- Stop loading indicator when closing
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

  -- Save the expanded chat history before sending
  vim.schedule(function()
    ChatDialog.save_file(true) -- true to skip rename
  end)

  -- Send to provider
  local full_prompt = chat_history .. "\n/user:\n" .. last_user_request
  message_handler.append_text(utils.state, "\n\n/assistant:\n")

  -- Start loading indicator
  utils.start_loading(utils.state.win, utils.state.buf)

  Assistant.ask(system_prompt, full_prompt, function(response)
    message_handler.append_text(utils.state, response)
  end, function()
    -- Stop loading indicator
    utils.stop_loading()
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

  -- Get current buffer contents and expand using the same logic as get_chat_history
  local chat_history = message_handler.get_chat_history(utils.state)

  -- Generate new filename and save expanded content
  local filename = generate_chat_filename()
  local file = io.open(filename, "w")
  if file then
    file:write(chat_history)
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

  -- Reset last_saved_file since this is a new chat
  utils.state.last_saved_file = nil
end

-- Update the clear function
function ChatDialog.clear()
  if utils.state.buf and api.nvim_buf_is_valid(utils.state.buf) then
    ChatDialog.save_and_create_new()
  end
end

function ChatDialog.setup()
  -- Add cancel keymap to config
  ChatDialog.config.keymaps = ChatDialog.config.keymaps or {}
  ChatDialog.config.keymaps.cancel = ChatDialog.config.keymaps.cancel or "<C-c>"

  -- Set up buffer-local keymap for cancellation
  vim.api.nvim_create_autocmd("FileType", {
    pattern = config.FILE_TYPE,
    callback = function(ev)
      vim.keymap.set("n", ChatDialog.config.keymaps.cancel, function()
        -- Trigger the cancel event
        vim.api.nvim_exec_autocmds("User", {
          pattern = "NVIMAIHTTPEscape",
          modeline = false,
        })
        -- Stop the loading spinner
        utils.stop_loading()
      end, { buffer = ev.buf, desc = "Cancel AI response" })
    end,
  })
end

return ChatDialog
