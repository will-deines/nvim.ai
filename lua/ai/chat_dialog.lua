local config = require("ai.config")
local Assistant = require("ai.assistant")
local api = vim.api
local path = require("plenary.path")
local scan = require("plenary.scandir")

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

local function get_file_content(file_path)
  local p = path:new(file_path)
  if p:exists() and not p:is_dir() then
    return p:read()
  end
  return nil
end

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

local function set_virtual_text(buf, line, text)
  api.nvim_buf_set_extmark(buf, api.nvim_create_namespace("chat_dialog"), line, 0, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
end

local function copy_code_block(buf, line)
  local lines = api.nvim_buf_get_lines(buf, line, -1, false)
  local code_block = {}
  local in_code_block = false
  for _, l in ipairs(lines) do
    if l:match("^```") then
      if in_code_block then
        break
      else
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(code_block, l)
    end
  end
  if #code_block > 0 then
    local code = table.concat(code_block, "\n")
    vim.fn.setreg("+", code)
    print("Code block copied to clipboard")
  else
    print("No code block found")
  end
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
  ChatDialog.append_text("\n\n/you:\n")
  vim.schedule(function()
    ChatDialog.save_file()
  end)
end

function ChatDialog.append_text(text)
  if
    not state.buf
    or not pcall(vim.api.nvim_buf_is_loaded, state.buf)
    or not pcall(vim.api.nvim_buf_get_option, state.buf, "buflisted")
  then
    return
  end

  vim.schedule(function()
    -- Get the last line and its content
    local last_line = api.nvim_buf_line_count(state.buf)
    local last_line_content = api.nvim_buf_get_lines(state.buf, -2, -1, false)[1] or ""

    -- Split the new text into lines
    local new_lines = vim.split(text, "\n", { plain = true })

    -- Append the first line to the last line of the buffer
    local updated_last_line = last_line_content .. new_lines[1]
    api.nvim_buf_set_lines(state.buf, -2, -1, false, { updated_last_line })

    -- Append the rest of the lines, if any
    if #new_lines > 1 then
      api.nvim_buf_set_lines(state.buf, -1, -1, false, { unpack(new_lines, 2) })
    end

    -- Add virtual text for code blocks
    for i, line in ipairs(new_lines) do
      if line:match("^```") then
        set_virtual_text(state.buf, last_line + i - 1, "Copy Code")
      end
    end

    -- Scroll to bottom
    if state.win and api.nvim_win_is_valid(state.win) then
      local new_last_line = api.nvim_buf_line_count(state.buf)
      local last_col = #api.nvim_buf_get_lines(state.buf, -2, -1, false)[1]
      api.nvim_win_set_cursor(state.win, { new_last_line, last_col })
    end
  end)
end

function ChatDialog.clear()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    return
  end

  api.nvim_buf_set_option(state.buf, "modifiable", true)
  api.nvim_buf_set_lines(state.buf, 0, -1, false, { "/you:", "", "" })
  state.last_saved_file = nil

  -- Set the cursor to the end of the two newlines after "/you:"
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_set_cursor(state.win, { 3, 0 })
  end
end

function ChatDialog.get_chat_history()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    return ""
  end

  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local chat_history = {}
  local current_entry = nil

  for _, line in ipairs(lines) do
    if line:match("^/you:") or line:match("^/assistant:") or line:match("^/system:") then
      if current_entry then
        table.insert(chat_history, current_entry)
      end
      current_entry = line
    elseif line:match("^/buf%s+(%d+)") then
      local bufnr = tonumber(line:match("^/buf%s+(%d+)"))
      if vim.api.nvim_buf_is_valid(bufnr) then
        local buf_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        table.insert(chat_history, line .. "\n" .. buf_name .. "\n```\n" .. buf_content .. "\n```")
      else
        table.insert(chat_history, line .. " (Invalid buffer)")
      end
    elseif line:match("^/file%s+(.+)") then
      local file_path = line:match("^/file%s+(.+)")
      local file_content = get_file_content(file_path)
      if file_content then
        table.insert(chat_history, line .. "\n```\n" .. file_content .. "\n```")
      else
        table.insert(chat_history, line .. " (File not found or unreadable)")
      end
    elseif line:match("^/dir%s+(.+)") then
      local dir_path = line:match("^/dir%s+(.+)")
      local files = scan.scan_dir(dir_path, {
        hidden = true,
        respect_gitignore = true,
        only_dirs = false,
        on_insert = function(file)
          local relative_path = vim.fn.fnamemodify(file, ":.")
          table.insert(chat_history, string.format("/file %s", relative_path))
        end,
      })
    elseif current_entry then
      current_entry = current_entry .. "\n" .. line
    end
  end
  if current_entry then
    table.insert(chat_history, current_entry)
  end
  return table.concat(chat_history, "\n")
end
function ChatDialog.send()
  local system_prompt = ChatDialog.get_system_prompt()
  local chat_history = ChatDialog.get_chat_history()
  local last_user_request = ChatDialog.last_user_request()
  local full_prompt = chat_history .. "\n/you:\n" .. last_user_request
  ChatDialog.append_text("\n\n/assistant:\n")
  Assistant.ask(system_prompt, full_prompt, ChatDialog.append_text, ChatDialog.on_complete)
end
function ChatDialog.get_system_prompt()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    return nil
  end
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:match("^/system%s(.+)") then
      return line:match("^/system%s(.+)")
    end
  end
  return nil
end
-- Function to get the last user request from the buffer
function ChatDialog.last_user_request()
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    return nil
  end
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local last_request = {}
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^/you") then
      -- We've found the start of the last user block
      break
    else
      table.insert(last_request, 1, line)
    end
  end
  if #last_request > 0 then
    return table.concat(last_request, "\n")
  else
    return nil
  end
end
function ChatDialog.setup()
  ChatDialog.config = vim.tbl_deep_extend("force", ChatDialog.config, config.config.ui or {})
  -- Create user commands
  api.nvim_create_user_command("ChatDialogToggle", ChatDialog.toggle, {})
  api.nvim_create_user_command("ChatDialogClear", ChatDialog.clear, {})
  -- Autocommand to handle virtual text clicks
  api.nvim_create_autocmd("CursorMoved", {
    pattern = "*",
    callback = function()
      local pos = api.nvim_win_get_cursor(0)
      local line = pos[1] - 1
      local col = pos[2]
      local extmarks = api.nvim_buf_get_extmarks(
        0,
        api.nvim_create_namespace("chat_dialog"),
        { line, 0 },
        { line, -1 },
        { details = true }
      )
      for _, extmark in ipairs(extmarks) do
        if extmark[4].virt_text and extmark[4].virt_text[1][1] == "Copy Code" then
          copy_code_block(0, line)
        end
      end
    end,
  })
end
return ChatDialog
