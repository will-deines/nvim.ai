local Utils = require("ai.utils")
local P = require("ai.providers")
local M = {}

M.API_KEY = "ANTHROPIC_API_KEY"

M.has = function()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

M.parse_response = function(data_stream, stream, opts)
  if not data_stream or data_stream == "" then
    return
  end

  if stream then
    -- Handle streaming data
    local lines = vim.split(data_stream, "\n")
    for _, line in ipairs(lines) do
      line = vim.trim(line)
      if line == "" then
        -- Skip empty lines
      elseif line:match("^data: ") then
        local data = line:sub(7) -- Remove "data: " prefix
        local success, json = pcall(vim.json.decode, data)
        if success then
          if json.delta and json.delta.type == "text_delta" then
            opts.on_chunk(json.delta.text)
          elseif json.event == "message_stop" then
            opts.on_complete(nil)
            return
          elseif json.event == "error" then
            opts.on_complete(json.error)
            return
          end
        else
          print("Failed to decode JSON from data:", data)
        end
      end
    end
  else
    -- Handle non-streaming data
    local success, json = pcall(vim.json.decode, data_stream)
    if success and json.content then
      local content = ""
      for _, part in ipairs(json.content) do
        if part.type == "text" then
          content = content .. part.text
        end
      end
      if content ~= "" then
        opts.on_chunk(content)
      end
      opts.on_complete(nil)
    else
      print("Failed to decode JSON from data:", data_stream)
    end
  end
end

M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local headers = {
    ["Content-Type"] = "application/json",
    ["x-api-key"] = os.getenv(M.API_KEY),
    ["anthropic-version"] = "2023-06-01",
  }
  -- Begin constructing the messages array
  local messages = {}

  -- Include the system prompt if available.  O-series doesn't allow a system prompt, so they're all user.
  if code_opts.system_prompt ~= nil then
    table.insert(messages, { role = "user", content = code_opts.system_prompt })
  end

  -- Include the document content as a system message or assistant message
  if code_opts.document ~= nil and code_opts.document ~= "" then
    table.insert(messages, { role = "user", content = code_opts.document })
  end

  -- Append the chat history messages
  for _, msg in ipairs(code_opts.chat_history) do
    table.insert(messages, { role = msg.role, content = msg.content })
  end

  -- Filter out any messages with null or empty content
  messages = vim.tbl_filter(function(msg)
    return msg.content ~= nil and msg.content ~= ""
  end, messages)

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/messages",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      system = code_opts.system_prompt,
      temperature = base.temperature,
      model = Utils.state.current_model,
      messages = messages,
      stream = false,
      max_tokens = base.max_tokens[Utils.state.current_model],
    }, body_opts),
  }
end

return M
