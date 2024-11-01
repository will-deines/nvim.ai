local scan = require("plenary.scandir")
local path = require("plenary.path")

M = {}

--- Read the content of multiple buffers, files, and directories into a single string
-- @param buffer_numbers table A list of buffer numbers
-- @param file_paths table A list of file and directory paths
-- @return string The concatenated content of all specified buffers, files, and directories

--- Parse the chat prompt and build the final prompt
-- @param input_string string The raw input string containing user prompt and slash commands
-- @return string The final prompt to be sent to the assistant

local function build_document(buffer_numbers, file_paths)
  local contents = {}
  local included_files = {}
  -- Process buffers
  for _, bufnr in ipairs(buffer_numbers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local full_path = vim.api.nvim_buf_get_name(bufnr)
      if full_path ~= "" and not included_files[full_path] then
        included_files[full_path] = true
        local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
        local buf_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        table.insert(
          contents,
          string.format(
            "<document>\n<filepath>%s</filepath>\n<filename>%s</filename>\n<content>\n``` %s\n%s\n```\n</content>\n</document>",
            full_path,
            vim.fn.fnamemodify(full_path, ":t"),
            filetype,
            buf_content
          )
        )
      end
    end
  end
  -- Process files and directories
  for _, file_path in ipairs(file_paths) do
    local p = path:new(file_path)
    if p:exists() then
      if p:is_dir() then
        local files_in_dir = scan.scan_dir(file_path, opts)
        for _, file_in_dir in ipairs(files_in_dir) do
          if not included_files[file_in_dir] then
            included_files[file_in_dir] = true
            local file_content = path:new(file_in_dir):read()
            local filetype = vim.fn.fnamemodify(file_in_dir, ":e")
            table.insert(
              contents,
              string.format(
                "<document>\n<filepath>%s</filepath>\n<filename>%s</filename>\n<content>\n``` %s\n%s\n```\n</content>\n</document>",
                file_in_dir,
                vim.fn.fnamemodify(file_in_dir, ":t"),
                filetype,
                file_content
              )
            )
          end
        end
      else
        if not included_files[file_path] then
          included_files[file_path] = true
          local file_content = p:read()
          local filetype = vim.fn.fnamemodify(file_path, ":e")
          table.insert(
            contents,
            string.format(
              "<document>\n<filepath>%s</filepath>\n<filename>%s</filename>\n<content>\n``` %s\n%s\n```\n</content>\n</document>",
              file_path,
              vim.fn.fnamemodify(file_path, ":t"),
              filetype,
              file_content
            )
          )
        end
      end
    end
  end
  return table.concat(contents, "\n\n")
end

M.parse_chat_prompt = function(input_string)
  local buffers = {}
  local files = {}
  local chat_history = {}
  local user_prompt_lines = {}
  local current_speaker = "user" -- Set initial speaker to "user"

  local valid_roles = { system = true, user = true, assistant = true }

  -- Parse slash commands and chat history
  for line in input_string:gmatch("[^\r\n]+") do
    local buf_match = line:match("^/buf%s+(%d+)")
    local file_match = line:match("^/file%s+(.+)")
    local speaker_match, rest_of_line = line:match("^/(%w+):%s*(.*)")

    if buf_match then
      table.insert(buffers, tonumber(buf_match))
    elseif file_match then
      table.insert(files, file_match)
    elseif speaker_match then
      local normalized_role = speaker_match:lower()
      if valid_roles[normalized_role] then
        if #user_prompt_lines > 0 then
          table.insert(chat_history, {
            role = current_speaker,
            content = table.concat(user_prompt_lines, "\n"),
          })
          user_prompt_lines = {}
        end
        current_speaker = normalized_role
        if rest_of_line and rest_of_line ~= "" then
          table.insert(user_prompt_lines, rest_of_line)
        end
      else
        print("Invalid role specified: " .. speaker_match)
      end
    else
      table.insert(user_prompt_lines, line)
    end
  end

  -- Add the last speaker's content
  if #user_prompt_lines > 0 then
    table.insert(chat_history, {
      role = current_speaker,
      content = table.concat(user_prompt_lines, "\n"),
    })
  end

  -- Build the document content
  local document = ""
  if #buffers > 0 or #files > 0 then
    document = build_document(buffers, files)
  end

  return {
    document = document,
    chat_history = chat_history,
  }
end

return M
