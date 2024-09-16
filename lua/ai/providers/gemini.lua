local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

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
  if data_stream == nil or data_stream == "" then
    return
  end

  -- Handle SSE (Server-Sent Events) stream
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    if line:match("^data: ") then
      local data = line:sub(7) -- Remove "data: " prefix
      if data == "[DONE]" then
        opts.on_complete(nil)
      else
        local success, json = pcall(vim.json.decode, data)
        if success and json.candidates and #json.candidates > 0 then
          local candidate = json.candidates[1]
          if candidate.content and candidate.content.parts then
            for _, part in ipairs(candidate.content.parts) do
              if part.text then
                opts.on_chunk(part.text)
              end
            end
          end
        else
          print("Failed to decode or process Gemini response:", data)
        end
      end
    end
  end
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
      topK = base.topK or nil, -- Only set if applicable
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
      vim.fn.getenv("GOOGLE_API_KEY") -- Alternatively, use M.API_KEY_ENV_VAR
    ),
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.json.encode(final_body),
  }
end

return M
