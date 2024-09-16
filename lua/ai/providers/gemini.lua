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
  print(data_stream)
  if data_stream == nil or data_stream == "" then
    return
  end
  -- Split the data stream by lines

  local last_chunk_time = socket.gettime()
  local timeout_seconds = 5 -- Adjust timeout as needed

  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line == "" then
      -- Skip empty lines
    elseif line:match("^data: ") then
      local data = line:sub(7)
      local success, json = pcall(vim.json.decode, data)
      if success then
        if json.candidates and #json.candidates > 0 then
          for _, candidate in ipairs(json.candidates) do
            if candidate.content and candidate.content.parts then
              for _, part in ipairs(candidate.content.parts) do
                opts.on_chunk(part.text)
              end
            end

            -- Update last_chunk_time for each valid chunk
            last_chunk_time = os.time()
          end
        end
      else
        print("Failed to decode JSON from data:", data)
      end
    else
      -- Handle ping and event lines if needed
      print("Received event:", line)
    end

    -- Check for timeout after processing each line
    if os.time() - last_chunk_time > timeout_seconds then
      opts.on_complete(nil) -- Assume stream ended due to timeout
      return
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
