local api = vim.api
local scan = require("plenary.scandir")
local path = require("plenary.path")

local M = {}

local function get_file_content(file_path)
  local p = path:new(file_path)
  if p:exists() and not p:is_dir() then
    return p:read()
  end
  return nil
end

function M.append_text(state, text)
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
    -- Scroll to bottom
    if state.win and api.nvim_win_is_valid(state.win) then
      local new_last_line = api.nvim_buf_line_count(state.buf)
      local last_col = #api.nvim_buf_get_lines(state.buf, -2, -1, false)[1]
      api.nvim_win_set_cursor(state.win, { new_last_line, last_col })
    end
  end)
end

function M.get_chat_history(state)
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    return ""
  end

  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local chat_history = {}
  local current_entry = nil

  for _, line in ipairs(lines) do
    -- Skip loading indicator lines with cancel instruction
    if line:match("^⌛ Waiting for response [⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] .*%(Press.*%)") then
      goto continue
    end

    if line:match("^/user:") or line:match("^/assistant:") or line:match("^/system:") then
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
      table.insert(chat_history, line)
      table.insert(chat_history, "\nDirectory contents:")
      local files = {}
      scan.scan_dir(dir_path, {
        hidden = true,
        respect_gitignore = true,
        add_dirs = false,
        on_insert = function(file)
          table.insert(files, file)
        end,
      })

      -- List all files
      for _, file in ipairs(files) do
        local relative_path = vim.fn.fnamemodify(file, ":.")
        table.insert(chat_history, "- " .. relative_path)
      end
      table.insert(chat_history, "")

      -- Expand content of each file
      for _, file in ipairs(files) do
        local content = get_file_content(file)
        if content then
          local ext = vim.fn.fnamemodify(file, ":e")
          local relative_path = vim.fn.fnamemodify(file, ":.")
          table.insert(chat_history, string.format("\nFile: %s\n```%s\n%s\n```\n", relative_path, ext, content))
        end
      end
    elseif current_entry then
      current_entry = current_entry .. "\n" .. line
    end
    ::continue::
  end

  if current_entry then
    table.insert(chat_history, current_entry)
  end

  return table.concat(chat_history, "\n")
end

function M.get_system_prompt(state)
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

function M.last_user_request(state)
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    return nil
  end
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local last_request = {}
  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^/user") then
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

local function should_exclude(file_path, exclude_patterns)
  -- Convert to relative path for consistent matching
  local relative_path = vim.fn.fnamemodify(file_path, ":.")

  for _, pattern in ipairs(exclude_patterns) do
    -- Check if any parent directory matches the exclude pattern
    local parts = vim.split(relative_path, "/")
    local current_path = ""

    for _, part in ipairs(parts) do
      current_path = current_path .. (current_path == "" and "" or "/") .. part
      if current_path:match(vim.fn.glob2regpat(pattern)) then
        return true
      end
    end
  end
  return false
end

local function get_directory_contents(dir_path)
  local config = require("ai.config")
  local exclude_patterns = config.get("file_completion").exclude_patterns
  local files = {}

  -- Track directories to skip
  local skip_dirs = {}

  scan.scan_dir(dir_path, {
    hidden = true,
    respect_gitignore = true,
    add_dirs = true, -- Include directories in scan
    on_insert = function(file_path)
      -- Skip if parent directory was excluded
      for skip_dir in pairs(skip_dirs) do
        if file_path:match("^" .. vim.pesc(skip_dir)) then
          return
        end
      end

      if should_exclude(file_path, exclude_patterns) then
        if vim.fn.isdirectory(file_path) == 1 then
          skip_dirs[file_path] = true
        end
        return
      end

      -- Only add files, not directories
      if vim.fn.isdirectory(file_path) ~= 1 then
        table.insert(files, file_path)
      end
    end,
  })

  return files
end

return M
