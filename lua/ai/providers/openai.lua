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
    { role = "system", content = opts.system_prompt },
    { role = "user", content = opts.base_prompt },
  }
end

M.parse_response = function(data_stream, _, opts)
  if not data_stream or data_stream == "" then
    return
  end

  -- Split the data stream by lines
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    -- Log everything that comes back
    print("Received line:", line)
    if line == "" then
      -- Skip empty lines
    elseif line == "data: [DONE]" then
      opts.on_complete(nil)
      return
    elseif vim.startswith(line, "data: ") then
      local data = line:sub(7) -- Remove "data: " prefix
      if data ~= "" then
        local success, json = pcall(vim.json.decode, data)
        if success and json.choices and json.choices[1] then
          local choice = json.choices[1]
          if choice.delta and choice.delta.content then
            opts.on_chunk(choice.delta.content)
          end
          if choice.finish_reason ~= vim.NIL and choice.finish_reason ~= nil then
            opts.on_complete(nil)
            return
          end
        else
          print("Failed to decode JSON from data:", data)
        end
      end
    else
      -- Handle non-streaming JSON responses
      local success, json = pcall(vim.json.decode, line)
      if success and json.choices and json.choices[1] then
        local content = json.choices[1].message and json.choices[1].message.content
        if content then
          opts.on_chunk(content)
        end
        opts.on_complete(nil)
      else
        print("Failed to decode JSON from data:", line)
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
      role = "system",
      content = code_opts.system_prompt or "", -- Ensure it's not null
    },
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
      stream = true,
    }, body_opts),
  }
end
return M
