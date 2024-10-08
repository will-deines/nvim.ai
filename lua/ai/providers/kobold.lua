local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local M = {}

M.has = function()
  -- Since the server is local, we can assume it's available.
  return true
end

M.parse_response = function(data_stream, _, opts)
  if not data_stream or data_stream == "" then
    return
  end

  -- Split the data stream by newlines
  local lines = vim.split(data_stream, "\n")
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line ~= "" then
      -- Check if the line is an event
      local event_type, data = line:match("^event:%s*(%w+)%s*data:%s*(.*)$")
      if event_type == "message" and data then
        local success, json = pcall(vim.json.decode, data)
        if success and json.token then
          -- Append the token to the output
          opts.on_chunk(json.token)
          -- Check if this is the final token
          if json.finish_reason == "stop" then
            opts.on_complete(nil)
            return
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
  }

  -- Build the body of the request
  local body = vim.tbl_deep_extend("force", {
    max_context_length = base.max_context_length or 131072,
    max_length = base.max_length or 131072,
    prompt = code_opts.base_prompt,
    temperature = base.temperature or 0.5,
    top_p = base.top_p or 0.9,
    top_k = base.top_k or 100,
    rep_pen = base.rep_pen or 1.1,
    rep_pen_range = base.rep_pen_range or 256,
    rep_pen_slope = base.rep_pen_slope or 1,
    -- Include other parameters as needed
  }, body_opts)

  return {
    url = Utils.trim(base.endpoint, { suffix = "/" }) .. "/api/extra/generate/stream",
    proxy = base.proxy,
    insecure = base.allow_insecure,
    headers = headers,
    body = body,
    stream = true, -- Enable streaming responses
  }
end

return M
