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
  if data_stream == nil or data_stream == "" then
    return
  end
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    if line:match("^data: ") then
      local data = line:sub(7) -- Remove "data: " prefix
      if data == "[DONE]" then
        opts.on_complete(nil)
      else
        local success, json = pcall(vim.json.decode, data)
        if success then
          if json.choices and #json.choices > 0 then
            local content = json.choices[1].delta and json.choices[1].delta.content or json.choices[1].text or ""
            opts.on_chunk(content)
          end
        else
          print("Failed to decode JSON from data:", data)
        end
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
      model = model or base.model,
      messages = messages,
      stream = true,
    }, body_opts),
  }
end

return M
