local lustache = require("ai.lustache")
local Prompts = require("ai.assistant.prompts")
local scan = require("plenary.scandir")
local path = require("plenary.path")
local config = require("ai.config")

M = {}

--- Get the filetype of the current buffer
-- @param bufnr number The buffer number
-- @return string|nil The filetype of the buffer, or nil if not determined
-- @return string|nil Error message if the buffer number is invalid
local function get_buffer_filetype()
  local bufnr = vim.api.nvim_get_current_buf()
  -- Ensure the buffer number is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "Invalid buffer number"
  end

  -- Get the filetype of the buffer
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

  -- If filetype is an empty string, it might mean it's not set
  if filetype == "" then
    -- Try to get the filetype from the buffer name
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname ~= "" then
      filetype = vim.filetype.match({ filename = bufname })
    end
  end

  -- If still empty, return "unknown"
  if filetype == "" then
    filetype = nil
  end

  return filetype
end

local function get_file_content(file_path)
  local p = path:new(file_path)
  if p:exists() and not p:is_dir() then
    return p:read()
  end
  return nil
end

--- Read the content of multiple buffers into a single string
-- @param buffer_numbers table A list of buffer numbers
-- @return string The concatenated content of all specified buffers
local function build_document(buffer_numbers, file_paths)
  local contents = {}

  -- Process buffers
  for _, bufnr in ipairs(buffer_numbers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local full_path = vim.api.nvim_buf_get_name(bufnr)
      local filename = vim.fn.fnamemodify(full_path, ":t")
      local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype") or ""
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local buffer_content = table.concat(lines, "\n")
      local formatted_content = string.format("%s\n```%s\n%s\n```", filename, filetype, buffer_content)
      table.insert(contents, formatted_content)
    end
  end

  -- Process files
  for _, file_path in ipairs(file_paths) do
    local filename = vim.fn.fnamemodify(file_path, ":t")
    local filetype = vim.filetype.match({ filename = file_path }) or ""
    local file_content = get_file_content(file_path)
    if file_content then
      local formatted_content = string.format("## File: %s\n\n```%s\n%s\n```", filename, filetype, file_content)
      table.insert(contents, formatted_content)
    end
  end

  return table.concat(contents, "\n\n")
end

local function get_prefix_suffix()
  -- Get the current buffer number
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get the current cursor line number
  local cur_line = vim.fn.line(".")

  -- Get the total number of lines in the buffer
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Get the prefix (lines before the cursor)
  local prefix = {}
  for i = 1, cur_line - 1 do
    table.insert(prefix, vim.api.nvim_buf_get_lines(bufnr, i - 1, i, true)[1])
  end

  -- Get the suffix (lines after the cursor)
  local suffix = {}
  for i = cur_line + 1, total_lines do
    table.insert(suffix, vim.api.nvim_buf_get_lines(bufnr, i - 1, i, true)[1])
  end

  return table.concat(prefix, "\n"), table.concat(suffix, "\n")
end

local function build_inline_document()
  local prefix, suffix = get_prefix_suffix()

  -- Add '<insert_here>' in the middle
  return table.concat({
    prefix,
    "<insert_here></insert_here>",
    suffix,
  }, "\n\n")
end

-- @param input_string string The raw input string containing user prompt and slash commands
-- @param language_name string|nil The name of the programming language (optional)
-- @param is_insert boolean Whether the operation is an insert operation
-- @return table A table containing parsed information:
--   - buffers: list of buffer numbers extracted from /buf commands
--   - user_prompt: the user's prompt text
--   - language_name: the determined language name
--   - content_type: "text" or "code" based on the language
--   - is_insert: boolean indicating if it's an insert operation
--   - rewrite_section: nil (TODO)
--   - is_truncated: nil (TODO)
local function build_inline_context(user_prompt, language_name, is_insert)
  -- TODO: rewrite section

  local document = build_inline_document()

  if language_name == nil then
    language_name = get_buffer_filetype()
  end

  local content_type = language_name == nil
    or language_name == "text"
    or language_name == "markdown" and "text"
    or "code"

  local result = {
    document_content = document,
    user_prompt = user_prompt,
    language_name = language_name,
    content_type = content_type,
    is_insert = is_insert, -- TODO: assist inline
    rewrite_section = nil, -- TODO: Rewrite section
    is_truncated = nil, -- TODO: The code length could be larger than the context
  }
  return result
end

M.parse_inline_assist_prompt = function(raw_prompt, language_name, is_insert)
  local context = build_inline_context(raw_prompt, language_name, is_insert)
  local prompt_template = Prompts.CONTENT_PROMPT
  local prompt = lustache:render(prompt_template, context)
  return prompt
end

M.parse_chat_prompt = function(input_string)
  local buffers = {}
  local files = {}
  local chat_history = {}
  local user_prompt_lines = {}
  local current_speaker = "you" -- Set initial speaker to "you"

  -- Parse slash commands and chat history
  for line in input_string:gmatch("[^\r\n]+") do
    local buf_match = line:match("^/buf%s+(%d+)")
    local file_match = line:match("^/file%s+(.+)")
    local speaker_match = line:match("^/(%w+):")

    if buf_match then
      table.insert(buffers, tonumber(buf_match))
    elseif file_match then
      table.insert(files, file_match)
    elseif speaker_match then
      if #user_prompt_lines > 0 then
        table.insert(chat_history, { role = current_speaker, content = table.concat(user_prompt_lines, "\n") })
        user_prompt_lines = {}
      end
      current_speaker = speaker_match
    else
      table.insert(user_prompt_lines, line)
    end
  end

  -- Add the last speaker's content
  if #user_prompt_lines > 0 then
    table.insert(chat_history, { role = current_speaker, content = table.concat(user_prompt_lines, "\n") })
  end

  -- Build the document content
  local document = ""
  if #buffers > 0 or #files > 0 then
    document = build_document(buffers, files)
  end

  -- Combine everything into the final prompt
  local final_prompt = {}
  if document ~= "" then
    table.insert(final_prompt, "<document>\n" .. document .. "\n</document>")
  end
  for _, entry in ipairs(chat_history) do
    table.insert(final_prompt, string.format("/%s: %s", entry.role, entry.content))
  end

  return table.concat(final_prompt, "\n\n")
end

return M
