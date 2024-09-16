local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

-- Environment Variable Name for Google API Key
M.API_KEY_ENV_VAR = "GEMINI_API_KEY"

-- Check if Gemini provider is available
M.has = function()
  return os.getenv(M.API_KEY_ENV_VAR) ~= nil
end

-- Handle Gemini's streamed response
M.parse_response = function(data_stream, event, opts)
  if type(data_stream) ~= "string" then
    Utils.error("Expected data_stream to be a string, got " .. type(data_stream))
    return
  end

  for line in data_stream:gmatch("[^\r\n]+") do
    if line:sub(1, 6) == "data: " then
      local json_str = line:sub(7) -- Remove 'data: ' prefix
      if json_str == "" then
        -- Skip empty data
        goto continue
      end
      local success, data = pcall(vim.json.decode, json_str)
      if success and data then
        if data.error then
          Utils.error("API Error: " .. data.error.message)
          opts.on_complete(data.error.message)
          return
        end
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
        -- Do not call opts.on_complete here
      else
        Utils.error("Failed to decode JSON: " .. json_str)
      end
    end
    ::continue::
  end
end

-- Construct the correct API call for Gemini
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local api_key = os.getenv(M.API_KEY_ENV_VAR)

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
