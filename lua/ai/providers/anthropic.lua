local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}
M.API_KEY = "ANTHROPIC_API_KEY"
M.has = function()
  return vim.fn.executable("curl") == 1 and os.getenv(M.API_KEY) ~= nil
end
M.parse_message = function(opts)
  local user_prompt = opts.base_prompt
  return {
    { role = "user", content = user_prompt },
  }
end
M.parse_response = function(json, event, opts)
  print("Received JSON in anthropic.lua:", vim.inspect(json))
  if event == "message_stop" then
    opts.on_complete(nil)
  elseif event == "content_block_delta" and json.delta and json.delta.type == "text_delta" then
    opts.on_chunk(json.delta.text)
  elseif event == "error" then
    opts.on_complete(json.error)
  else
    print("Unhandled event type:", event)
  end
end
M.parse_curl_args = function(provider, code_opts)
  local base, body_opts = P.parse_config(provider)
  local headers = {
    ["Content-Type"] = "application/json",
    ["x-api-key"] = os.getenv(M.API_KEY),
    ["anthropic-version"] = "2023-06-01",
  }
  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/v1/messages",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = vim.tbl_deep_extend("force", {
      model = base.model,
      system = code_opts.system_prompt,
      messages = M.parse_message(code_opts),
      stream = true,
      max_tokens = base.max_tokens or 4096,
      temperature = base.temperature or 0.7,
    }, body_opts),
  }
end
return M
