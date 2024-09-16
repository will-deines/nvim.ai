local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}

-- Environment Variable Name for Gemini API Key
M.API_KEY_ENV_VAR = "GEMINI_API_KEY"

-- Check if Gemini provider is available
M.has = function()
  return os.getenv(M.API_KEY_ENV_VAR) ~= nil
end

-- Parse the content into Gemini's expected `contents` structure
M.parse_message = function(opts)
  local user_prompt = opts.base_prompt
  return {
    {
      parts = {
        {
          text = user_prompt,
        },
      },
    },
  }
end

-- Handle Gemini's streamed response
M.parse_response = function(data_stream, event, opts)
  if type(data_stream) ~= "table" then
    Utils.error("Expected data_stream to be a table, got " .. type(data_stream))
    return
  end

  -- Check if the stream has completed
  if data_stream.done then
    opts.on_complete(nil)
    return
  end

  -- Process the candidates
  if data_stream.candidates and #data_stream.candidates > 0 then
    local candidate = data_stream.candidates[1]
    if candidate.content and candidate.content.parts then
      for _, part in ipairs(candidate.content.parts) do
        if part.text then
          opts.on_chunk(part.text)
        end
      end
    end
  end

  -- Optionally handle promptFeedback, usageMetadata if needed
end

-- Construct the correct API call for Gemini
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. os.getenv(M.API_KEY_ENV_VAR),
  }

  -- Construct the request body as per Gemini's API
  local request_body = {
    model = base.model, -- e.g., "gemini-1.5-flash"
    generationConfig = {
      maxOutputTokens = base.maxOutputTokens or 4096,
      temperature = base.temperature or 0.7,
      topP = base.topP or 1.0,
      topK = base.topK, -- Optional: Only set if applicable
    },
    contents = {
      {
        parts = {
          {
            text = code_opts.base_prompt,
          },
        },
      },
    },
  }

  -- Merge with any additional body options
  local final_body = vim.tbl_deep_extend("force", request_body, body_opts)

  return {
    url = string.format(
      "https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse&key=%s",
      base.model,
      os.getenv("GOOGLE_API_KEY") -- Ensure this matches your config or environment variable
    ),
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.json.encode(final_body),
  }
end

return M
