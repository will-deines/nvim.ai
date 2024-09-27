local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}
M.API_KEY = "OPENAI_API_KEY"
M.has = function()
  return os.getenv(M.API_KEY) and true or false
end

M.parse_message = function(opts)
  local user_prompt = opts.base_prompt
  return {
    { role = "user", content = opts.base_prompt },
  }
end

M.parse_response = function(data_stream, event, opts)
  if data_stream == nil or data_stream == "" then
    print("Empty data_stream, returning")
    return
  end
  print(type(data_stream))
  -- If data_stream is already a table (decoded JSON), handle it directly
  if type(data_stream) == "table" then
    if data_stream.choices and #data_stream.choices > 0 then
      local choice = data_stream.choices[1]
      if choice.message then
        opts.on_chunk(choice.message.content or "")
      end
      if choice.finish_reason and choice.finish_reason ~= vim.NIL then
        opts.on_complete(nil)
      end
    end
    return
  end
  -- If it's not valid JSON, it might be a stream chunk
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    print(line)
    if line:match("^data: ") then
      local data = line:sub(7) -- Remove "data: " prefix
      local success, json = pcall(vim.json.decode, data)
      if success then
        if json.choices and #json.choices > 0 then
          local choice = json.choices[0]
          if choice.message then
            opts.on_chunk(choice.message.content or "")
          end
          if choice.finish_reason and choice.finish_reason ~= vim.NIL then
            opts.on_complete(nil)
          end
        end
        if json.usage then
          print("Usage:", vim.inspect(json.usage))
        end
      else
        print("Failed to decode JSON from data:", data)
      end
    end
  end
end

M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. os.getenv(M.API_KEY),
  }
  local messages = {
    {
      role = "user",
      content = code_opts.base_prompt or "", -- Ensure it's not null
    },
  }
  -- Filter out any messages with null content
  messages = vim.tbl_filter(function(msg)
    return msg.content ~= nil and msg.content ~= ""
  end, messages)
  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/chat/completions",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      messages = messages,
      -- Fixed parameters for o1-models
      temperature = 1,
      top_p = 1,
      n = 1,
      presence_penalty = 0,
      frequency_penalty = 0,
      stream = false,
    }, body_opts),
  }
end
return M
