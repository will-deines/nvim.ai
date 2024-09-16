local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")

local M = {}

M.API_KEY = "GEMINI_API_KEY"

function M.has()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end

function M.parse_response(data_stream, _, opts)
  Utils.debug("Gemini parse_response called", { title = "Gemini Debug" })
  Utils.debug("Data stream: " .. vim.inspect(data_stream), { title = "Gemini Debug" })

  if data_stream == nil or data_stream == "" then
    Utils.debug("Empty data stream", { title = "Gemini Debug" })
    return
  end

  if data_stream == "[DONE]" then
    Utils.debug("Stream complete", { title = "Gemini Debug" })
    opts.on_complete(nil)
    return
  end

  if type(data_stream) == "string" then
    Utils.debug("Attempting to parse JSON from string", { title = "Gemini Debug" })
    local success, parsed_data = pcall(vim.json.decode, data_stream)
    if success then
      data_stream = parsed_data
    else
      Utils.debug("Failed to parse JSON: " .. parsed_data, { title = "Gemini Debug" })
      return
    end
  end

  if data_stream.candidates and #data_stream.candidates > 0 then
    Utils.debug("Processing candidates", { title = "Gemini Debug" })
    for i, candidate in ipairs(data_stream.candidates) do
      Utils.debug("Processing candidate " .. i, { title = "Gemini Debug" })
      if candidate.content and candidate.content.parts then
        for j, part in ipairs(candidate.content.parts) do
          if part.text then
            Utils.debug("Sending chunk from candidate " .. i .. ", part " .. j, { title = "Gemini Debug" })
            opts.on_chunk(part.text)
          else
            Utils.debug("No text in part " .. j .. " of candidate " .. i, { title = "Gemini Debug" })
          end
        end
      else
        Utils.debug("No content or parts in candidate " .. i, { title = "Gemini Debug" })
      end
    end
  else
    Utils.debug("No candidates in response", { title = "Gemini Debug" })
  end

  if data_stream.promptFeedback then
    Utils.debug("Prompt feedback: " .. vim.inspect(data_stream.promptFeedback), { title = "Gemini Debug" })
    if data_stream.promptFeedback.blockReason then
      Utils.debug("Prompt blocked: " .. data_stream.promptFeedback.blockReason, { title = "Gemini Debug" })
      opts.on_complete("Prompt blocked: " .. data_stream.promptFeedback.blockReason)
    end
  end

  if data_stream.usageMetadata then
    Utils.debug("Usage metadata: " .. vim.inspect(data_stream.usageMetadata), { title = "Gemini Debug" })
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
          text = code_opts.base_prompt,
        },
      },
    },
  }

  local body = {
    contents = contents,
    generationConfig = {},
  }

  if code_opts.system_prompt then
    body.systemPrompt = code_opts.system_prompt
  end

  if base.temperature then
    body.generationConfig.temperature = base.temperature
  end

  if base.maxOutputTokens then
    body.generationConfig.maxOutputTokens = base.maxOutputTokens
  end

  if base.topP then
    body.generationConfig.topP = base.topP
  end

  if base.topK then
    body.generationConfig.topK = base.topK
  end

  if vim.tbl_isempty(body.generationConfig) then
    body.generationConfig = nil
  end

  local url = Utils.trim(base.endpoint, { suffix = "/" })
    .. "/v1beta/models/"
    .. base.model
    .. ":streamGenerateContent?alt=sse&key="
    .. os.getenv(M.API_KEY)

  Utils.debug("Gemini full request:", { title = "Gemini Debug" })
  Utils.debug("URL: " .. url, { title = "Gemini Debug" })
  Utils.debug("Headers: " .. vim.inspect(headers), { title = "Gemini Debug" })
  Utils.debug("Body: " .. vim.inspect(body), { title = "Gemini Debug" })

  return {
    url = url,
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", body, body_opts),
  }
end

return M
