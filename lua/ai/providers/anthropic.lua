local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}
M.API_KEY = "ANTHROPIC_API_KEY"
M.has = function()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end
M.parse_message = function(opts)
  local user_prompt = opts.base_prompt
  return {
    { role = "user", content = user_prompt },
  }
end
M.parse_response = function(data_stream, event, opts)
  print("Received data_stream in anthropic.lua:", vim.inspect(data_stream))

  if data_stream == nil or data_stream == "" then
    print("Empty data_stream, returning")
    return
  end

  -- If data_stream is already a table (decoded JSON), handle it directly
  if type(data_stream) == "table" then
    if event == "message_start" then
      -- Handle message_start event if needed
    elseif event == "content_block_start" then
      -- Handle content_block_start event if needed
    elseif event == "content_block_delta" and data_stream.delta and data_stream.delta.type == "text_delta" then
      opts.on_chunk(data_stream.delta.text)
    elseif event == "content_block_stop" then
      -- Handle content_block_stop event if needed
    elseif event == "message_delta" then
      -- Handle message_delta event if needed
    elseif event == "message_stop" then
      opts.on_complete(nil)
    elseif event == "error" then
      opts.on_complete(data_stream.error)
    else
      print("Unhandled event type:", event)
    end
    return
  end

  -- Try to decode the entire data_stream as JSON
  local success, json = pcall(vim.json.decode, data_stream)
  if success then
    print("Successfully decoded JSON:", vim.inspect(json))
    if json.choices and #json.choices > 0 then
      local content = json.choices[1].delta and json.choices[1].delta.content or json.choices[1].text or ""
      opts.on_chunk(content)
    end
    opts.on_complete(nil)
    return
  end

  -- If it's not valid JSON, it might be a stream chunk
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    if line:match("^data: ") then
      local data = line:sub(7) -- Remove "data: " prefix
      success, json = pcall(vim.json.decode, data)
      if success then
        print("Successfully decoded JSON from data:", vim.inspect(json))
        if event == "message_start" then
          -- Handle message_start event if needed
        elseif event == "content_block_start" then
          -- Handle content_block_start event if needed
        elseif event == "content_block_delta" and json.delta and json.delta.type == "text_delta" then
          opts.on_chunk(json.delta.text)
        elseif event == "content_block_stop" then
          -- Handle content_block_stop event if needed
        elseif event == "message_delta" then
          -- Handle message_delta event if needed
        elseif event == "message_stop" then
          opts.on_complete(nil)
        elseif event == "error" then
          opts.on_complete(json.error)
        else
          print("Unhandled event type:", event)
        end
      else
        print("Failed to decode JSON from data:", data)
      end
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
  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/messages",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      system = code_opts.system_prompt,
      messages = M.parse_message(code_opts),
      stream = true,
      max_tokens = base.max_tokens or 4096,
      temperature = base.temperature or 0.7,
    }, body_opts),
  }
end
return M
