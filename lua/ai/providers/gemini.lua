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
    Utils.debug({
      msg = "Failed to parse Gemini JSON",
      data = data,
      error = json,
    }, { title = "Gemini JSON Parse Error" })
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
        Utils.debug({
          msg = "Processing candidate part",
          text_length = #part.text,
        }, { title = "Gemini Response" })
        opts.on_chunk(part.text)
      end
    end
  else
    Utils.debug({
      msg = "Invalid candidate structure",
      candidate = candidate,
    }, { title = "Gemini Response Error" })
  end
end
M.parse_response = function(data_stream, stream, opts)
  if not data_stream or data_stream == "" then
    Utils.debug("Empty data stream received", { title = "Gemini Warning" })
    return
  end
  Utils.debug({
    msg = "Received data stream",
    stream_mode = stream,
    data_length = #data_stream,
  }, { title = "Gemini Debug" })
  if stream then
    -- Handle streaming SSE response
    local lines = vim.split(data_stream, "\n")
    Utils.debug({
      msg = "Processing SSE stream",
      line_count = #lines,
    }, { title = "Gemini Stream" })
    for i, line in ipairs(lines) do
      line = vim.trim(line)
      Utils.debug({
        msg = "Processing SSE line",
        line_number = i,
        line = line,
      }, { title = "Gemini Stream Line" })
      if line:match("^data: ") then
        local data = line:sub(7) -- Remove "data: " prefix
        if data == "[DONE]" then
          Utils.debug("Stream complete", { title = "Gemini Stream" })
          opts.on_complete(nil)
          return
        end
        local json = parse_json(data, opts)
        if json then
          if json.error then
            Utils.debug({
              msg = "Gemini API Error",
              error = json.error,
            }, { title = "Gemini Error" })
            opts.on_complete(vim.inspect(json.error))
            return
          end
          if json.candidates and #json.candidates > 0 then
            process_candidate(json.candidates[1], opts)
          else
            Utils.debug({
              msg = "No candidates in response",
              json = json,
            }, { title = "Gemini Warning" })
          end
        end
      end
    end
  else
    -- Handle complete response
    Utils.debug("Processing complete response", { title = "Gemini Response" })
    local json = parse_json(data_stream, opts)
    if json then
      if json.error then
        Utils.debug({
          msg = "Gemini API Error",
          error = json.error,
        }, { title = "Gemini Error" })
        opts.on_complete(vim.inspect(json.error))
        return
      end
      if json.candidates and #json.candidates > 0 then
        process_candidate(json.candidates[1], opts)
        opts.on_complete(nil)
      else
        Utils.debug({
          msg = "No candidates in response",
          json = json,
        }, { title = "Gemini Warning" })
      end
    end
  end
end
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  Utils.debug({
    msg = "Parsing curl args",
    provider = provider,
    current_model = Utils.state.current_model,
    base_config = base,
  }, { title = "Gemini Request" })
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
    Utils.debug({
      msg = "Added generation config",
      config = request_body.generationConfig,
    }, { title = "Gemini Request" })
  end
  -- Add safety settings if configured
  if base.safetySettings then
    request_body.safetySettings = base.safetySettings
    Utils.debug({
      msg = "Added safety settings",
      settings = request_body.safetySettings,
    }, { title = "Gemini Request" })
  end
  -- Add system instruction if present
  if code_opts.system_prompt then
    request_body.systemInstruction = {
      parts = { { text = code_opts.system_prompt } },
    }
    Utils.debug({
      msg = "Added system instruction",
      length = #code_opts.system_prompt,
    }, { title = "Gemini Request" })
  end
  -- Build contents array from chat history
  for i, msg in ipairs(code_opts.chat_history) do
    if msg.content and msg.content ~= "" then
      table.insert(request_body.contents, {
        parts = { { text = msg.content } },
        role = msg.role == "assistant" and "model" or "user",
      })
      Utils.debug({
        msg = "Added chat message",
        message_index = i,
        role = msg.role,
        content_length = #msg.content,
      }, { title = "Gemini Request" })
    end
  end
  -- Add document content if present
  if code_opts.document and code_opts.document ~= "" then
    table.insert(request_body.contents, {
      parts = { { text = code_opts.document } },
      role = "user",
    })
    Utils.debug({
      msg = "Added document content",
      length = #code_opts.document,
    }, { title = "Gemini Request" })
  end
  -- Ensure we have at least one content part as required by API
  if #request_body.contents == 0 then
    table.insert(request_body.contents, {
      parts = { { text = "Hello" } },
      role = "user",
    })
    Utils.debug("Added default content", { title = "Gemini Request" })
  end
  -- Merge with any additional body options
  request_body = vim.tbl_deep_extend("force", request_body, body_opts)
  -- Build URL with correct query parameter structure
  local endpoint = base.stream and ":streamGenerateContent" or ":generateContent"
  local query = base.stream and "?alt=sse&" or "?"
  local url = string.format(
    "https://generativelanguage.googleapis.com/v1beta/models/%s%s%skey=%s",
    Utils.state.current_model,
    endpoint,
    query,
    os.getenv(M.API_KEY)
  )
  Utils.debug({
    msg = "Final request configuration",
    url = url:gsub(os.getenv(M.API_KEY), "REDACTED"), -- Don't log API key
    stream = base.stream,
    content_count = #request_body.contents,
  }, { title = "Gemini Request" })
  return {
    url = url,
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
