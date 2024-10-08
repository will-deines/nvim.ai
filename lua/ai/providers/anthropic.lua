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
  if data_stream == nil or data_stream == "" then
    return
  end

  -- Split the data stream by lines
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line == "" then
      -- Skip empty lines
    elseif line:match("^event: ") then
      event = line:match("^event: (.+)$")
      opts.current_event = event
    elseif line:match("^data: ") then
      local data = line:sub(7) -- Remove "data: " prefix
      local success, json = pcall(vim.json.decode, data)
      if success then
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
      model = model or base.model,
      system = code_opts.system_prompt,
      messages = M.parse_message(code_opts),
      stream = true,
      max_tokens = base.max_tokens or 4096,
      temperature = base.temperature or 0.7,
    }, body_opts),
  }
end

return M
