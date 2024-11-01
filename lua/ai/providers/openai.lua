local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}
M.API_KEY = "OPENAI_API_KEY"
M.has = function()
  return os.getenv(M.API_KEY) and true or false
end
M.parse_message = function(opts)
  return {
    { role = "system", content = opts.system_prompt },
    { role = "user", content = opts.base_prompt },
  }
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
      print("Received line:", line)
      if line == "" then
        -- Skip empty lines
      elseif line == "data: [DONE]" then
        opts.on_complete(nil)
        return
      elseif vim.startswith(line, "data: ") then
        local data = line:sub(7) -- Remove "data: " prefix
        if data ~= "" then
          local success, json = pcall(vim.json.decode, data)
          if success and json.choices and json.choices[1] then
            local choice = json.choices[1]
            if choice.delta and choice.delta.content then
              opts.on_chunk(choice.delta.content)
            end
            if choice.finish_reason ~= vim.NIL and choice.finish_reason ~= nil then
              opts.on_complete(nil)
              return
            end
          else
            print("Failed to decode JSON from data:", data)
          end
        end
      end
    end
  else
    -- Handle non-streaming data
    local success, json = pcall(vim.json.decode, data_stream)
    if success and json.choices and json.choices[1] then
      local content = json.choices[1].message and json.choices[1].message.content
      if content then
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
    ["Authorization"] = "Bearer " .. os.getenv(M.API_KEY),
  }

  -- Begin constructing the messages array
  local messages = {}

  -- Include the system prompt if available
  if code_opts.system_prompt ~= nil then
    table.insert(messages, { role = "system", content = code_opts.system_prompt })
  end

  -- Include the document content as a system message or assistant message
  if code_opts.document ~= nil and code_opts.document ~= "" then
    table.insert(messages, { role = "system", content = code_opts.document })
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
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = Utils.state.current_model,
      messages = messages,
      stream = base.stream,
      max_tokens = base.max_tokens[Utils.state.current_model],
    }, body_opts),
  }
end
return M
