local Utils = require("ai.utils")
local P = require("ai.providers")
local M = {}
M.API_KEY = "OPENAI_API_KEY"
M.has = function()
  return os.getenv(M.API_KEY) and true or false
end
M.parse_message = function(opts)
  local user_prompt = opts.base_prompt
  return {
    { role = "user", content = opts.base_prompt },
  }
end
M.parse_response = function(data_stream, event, opts)
  if data_stream == nil or data_stream == "" then
    print("Empty data_stream, returning")
    return
  end
  local success, json = pcall(vim.json.decode, data_stream)
  if success then
    if json.choices and #json.choices > 0 then
      local choice = json.choices[1] -- Always take the first choice (index 0)
      if choice and choice.message then
        opts.on_chunk(choice.message.content or "")
      end
      if choice and choice.finish_reason and choice.finish_reason ~= vim.NIL then
        opts.on_complete(nil)
      end
    end
    if json.usage then
      print("Usage:", vim.inspect(json.usage))
    end
  else
    print("Failed to decode JSON from data:", data_stream)
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
      model = base.model,
      messages = messages,
      temperature = base.temperature,
      top_p = base.top_p,
      n = base.n,
      presence_penalty = base.presence_penalty,
      frequency_penalty = base.frequency_penalty,
      stream = false,
    }, body_opts),
  }
end

return M
