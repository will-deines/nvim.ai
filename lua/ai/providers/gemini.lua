local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}

-- Environment Variable Name for Google API Key
M.API_KEY = "GEMINI_API_KEY"

-- Check if Gemini provider is available
M.has = function()
  return os.getenv(M.API_KEY)
end

-- Handle Gemini's streamed response
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

-- Construct the correct API call for Gemini
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local api_key = os.getenv(M.API_KEY)

  local headers = {
    ["Content-Type"] = "application/json",
  }

  -- Construct the request body as per API documentation
  local request_body = {
    contents = {
      {
        parts = {
          {
            text = code_opts.base_prompt, -- User's prompt text
          },
        },
      },
    },
    systemInstruction = {
      parts = {
        {
          text = code_opts.system_prompt or "", -- System instructions if any
        },
      },
    },
    generationConfig = {
      maxOutputTokens = base.maxOutputTokens or 1024,
      temperature = base.temperature or 0.7,
      topP = base.topP or 1.0,
      topK = base.topK, -- If applicable
    },
  }

  -- Filter out fields that should not be at the root level
  local allowed_body_opts = {}
  for key, value in pairs(body_opts) do
    if key ~= "temperature" and key ~= "topP" and key ~= "topK" and key ~= "maxOutputTokens" then
      allowed_body_opts[key] = value
    else
      -- Place these fields inside generationConfig
      request_body.generationConfig[key] = value
    end
  end

  -- Merge allowed_body_opts into request_body
  local final_body = vim.tbl_deep_extend("force", request_body, allowed_body_opts)

  -- Construct the URL with the API key
  local model_name = base.model or "gemini-1.5-flash"
  local url = string.format(
    "https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse&key=%s",
    model_name,
    api_key
  )

  return {
    url = url,
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = final_body,
    stream = true, -- Enable streaming responses
  }
end

return M
