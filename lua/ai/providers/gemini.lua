local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

-- Environment Variable Name for Google API Key
M.API_KEY_ENV_VAR = "GOOGLE_API_KEY"

-- Check if Gemini provider is available
M.has = function()
  return os.getenv(M.API_KEY_ENV_VAR) ~= nil
end

-- Handle Gemini's streamed response
M.parse_response = function(data_stream, event, opts)
  -- Add a print statement to show the raw data_stream
  print("Raw Data Stream:", data_stream)
  if type(data_stream) ~= "string" then
    Utils.error("Expected data_stream to be a string, got " .. type(data_stream))
    return
  end

  -- Split the stream into JSON objects
  local json_objects = vim.split(data_stream, "\n")

  for _, json_str in ipairs(json_objects) do
    if json_str ~= "" then
      local success, data = pcall(vim.json.decode, json_str)
      if success then
        -- Check if the stream has completed
        if data.done then
          opts.on_complete(nil)
          return
        end

        -- Process the candidates
        if data.candidates and #data.candidates > 0 then
          local candidate = data.candidates[1]
          if candidate.content and candidate.content.parts then
            for _, part in ipairs(candidate.content.parts) do
              if part.text then
                opts.on_chunk(part.text)
              end
            end
          end
        end
      else
        Utils.error("Failed to decode JSON: " .. json_str)
      end
    end
  end
end

-- Construct the correct API call for Gemini
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local api_key = os.getenv(M.API_KEY_ENV_VAR)

  local headers = {
    ["Content-Type"] = "application/json",
    -- Authorization header is not required when using API key in URL
    -- ["Authorization"] = "Bearer " .. api_key,
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

  -- Merge with any additional body options
  local final_body = vim.tbl_deep_extend("force", request_body, body_opts)

  -- Construct the full URL with the model path parameter
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
