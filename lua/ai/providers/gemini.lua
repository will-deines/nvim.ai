local Utils = require("ai.utils")
local P = require("ai.providers")
local M = {}
M.API_KEY = "GEMINI_API_KEY"
M.has = function()
  return os.getenv(M.API_KEY) ~= nil
end
-- Helper function to safely parse JSON and handle errors
local function parse_json(data, opts)
  local success, json = pcall(vim.json.decode, data)
  if not success then
    Utils.debug("Failed to parse Gemini JSON: " .. data)
    opts.on_complete("JSON parse error")
    return nil
  end
  return json
end
-- Helper function to process candidate content
local function process_candidate(candidate, opts)
  if candidate.content and candidate.content.parts then
    for _, part in ipairs(candidate.content.parts) do
      if part.text then
        opts.on_chunk(part.text)
      end
    end
  end
end
M.parse_response = function(data_stream, stream, opts)
  if not data_stream or data_stream == "" then
    return
  end
  if stream then
    -- Handle streaming SSE response
    local lines = vim.split(data_stream, "\n")
    for _, line in ipairs(lines) do
      line = vim.trim(line)
      if line:match("^data: ") then
        local data = line:sub(7) -- Remove "data: " prefix
        if data == "[DONE]" then
          opts.on_complete(nil)
          return
        end

        local json = parse_json(data, opts)
        if json and json.candidates and #json.candidates > 0 then
          process_candidate(json.candidates[1], opts)
        end
      end
    end
  else
    -- Handle complete response
    local json = parse_json(data_stream, opts)
    if json and json.candidates and #json.candidates > 0 then
      process_candidate(json.candidates[1], opts)
      opts.on_complete(nil)
    end
  end
end
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)

  -- Build request body according to API spec
  local request_body = {
    contents = {},
  }
  -- Add generation config from provider config
  if base.generationConfig then
    request_body.generationConfig = {
      maxOutputTokens = base.generationConfig.maxOutputTokens[Utils.state.current_model],
      temperature = base.generationConfig.temperature,
      topP = base.generationConfig.topP,
      topK = base.generationConfig.topK,
    }
  end
  -- Add safety settings if configured
  if base.safetySettings then
    request_body.safetySettings = base.safetySettings
  end
  -- Add system instruction if present
  if code_opts.system_prompt then
    request_body.systemInstruction = {
      parts = { { text = code_opts.system_prompt } },
    }
  end
  -- Build contents array from chat history
  for _, msg in ipairs(code_opts.chat_history) do
    if msg.content and msg.content ~= "" then
      table.insert(request_body.contents, {
        parts = { { text = msg.content } },
        role = msg.role == "assistant" and "model" or "user",
      })
    end
  end
  -- Add document content if present
  if code_opts.document and code_opts.document ~= "" then
    table.insert(request_body.contents, {
      parts = { { text = code_opts.document } },
      role = "user",
    })
  end
  -- Ensure we have at least one content part as required by API
  if #request_body.contents == 0 then
    table.insert(request_body.contents, {
      parts = { { text = "Hello" } },
      role = "user",
    })
  end
  -- Merge with any additional body options
  request_body = vim.tbl_deep_extend("force", request_body, body_opts)
  -- Build URL with correct query parameter structure
  local endpoint = base.stream and ":streamGenerateContent" or ":generateContent"
  local query = base.stream and "?alt=sse&" or "?"

  return {
    url = string.format(
      "https://generativelanguage.googleapis.com/v1beta/models/%s%s%skey=%s",
      Utils.state.current_model,
      endpoint,
      query,
      os.getenv(M.API_KEY)
    ),
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = request_body,
    stream = base.stream or false,
  }
end
return M
