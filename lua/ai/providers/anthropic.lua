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
    ["X-Api-Key"] = os.getenv(M.API_KEY),
    ["Anthropic-Version"] = "2023-06-01",
    ["Anthropic-Beta"] = "prompt-caching-2024-07-31",
  }

  local messages = {}
  local system = {}

  -- Handle system prompt and merge with document
  local system_text = code_opts.system_prompt or ""
  if code_opts.document and #code_opts.document > 0 then
    system_text = system_text .. "\n\n" .. code_opts.document
  end

  if #system_text > 0 then
    table.insert(system, {
      type = "text",
      text = system_text,
      cache_control = { type = "ephemeral" },
    })
  end

  -- Process chat history
  for _, msg in ipairs(code_opts.chat_history) do
    if msg.role == "user" or msg.role == "assistant" then
      local content_parts = {}
      if msg.content and #msg.content > 0 then
        table.insert(content_parts, {
          type = "text",
          text = msg.content,
        })
      end
      if #content_parts > 0 then
        table.insert(messages, {
          role = msg.role,
          content = content_parts,
        })
      end
    end
  end

  -- Filter out messages with empty text content
  messages = vim.tbl_filter(function(msg)
    if msg.content and #msg.content > 0 then
      for _, part in ipairs(msg.content) do
        if part.text and #part.text > 0 then
          return true
        end
      end
    end
    return false
  end, messages)

  local max_tokens = base.max_tokens and base.max_tokens[Utils.state.current_model] or 8192

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/messages",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      system = system,
      temperature = base.temperature,
      model = Utils.state.current_model,
      messages = messages,
      stream = base.stream or false,
      max_tokens = max_tokens,
    }, body_opts),
  }
end

return M
