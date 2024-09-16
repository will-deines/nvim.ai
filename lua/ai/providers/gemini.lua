local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

M.API_KEY = "GEMINI_API_KEY"

function M.has()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

function M.parse_response(data_stream, _, opts)
  if data_stream == nil or data_stream == "" then
    return
  end

  local data_match = data_stream:match("^data: (.+)$")
  if data_match == "[DONE]" then
    opts.on_complete(nil)
    return
  end

  local success, json = pcall(vim.json.decode, data_match)
  if success then
    if json.candidates and #json.candidates > 0 then
      for _, candidate in ipairs(json.candidates) do
        if candidate.content and candidate.content.parts then
          for _, part in ipairs(candidate.content.parts) do
            if part.text then
              opts.on_chunk(part.text)
            end
          end
        end
      end
    end

    if json.promptFeedback then
      -- Handle prompt feedback if needed
    end

    if json.usageMetadata then
      -- Handle usage metadata if needed
    end
  else
    print("Failed to decode JSON from data:", data_match)
  end
end

function M.parse_curl_args(provider, code_opts)
  local base, body_opts = P.parse_config(provider)

  local headers = {
    ["Content-Type"] = "application/json",
  }

  local contents = {
    {
      parts = {
        {
          text = code_opts.system_prompt .. "\n\n" .. code_opts.base_prompt,
        },
      },
    },
  }

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" })
      .. "/v1beta/models/"
      .. base.model
      .. ":streamGenerateContent?alt=sse&key="
      .. os.getenv(M.API_KEY),
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      contents = contents,
      generationConfig = {
        temperature = base.temperature or 0.7,
        maxOutputTokens = base.max_tokens or 1024,
        topP = 1,
        topK = 1,
      },
    }, body_opts),
  }
end

return M
