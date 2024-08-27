local api = vim.api
local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local curl = require("plenary.curl")

local M = {}

M.CANCEL_PATTERN = "NVIMAIHTTPEscape"

local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

local function safe_json_decode(str)
  local success, result = pcall(vim.json.decode, str)
  if success then
    return result
  else
    return nil
  end
end

local function parse_stream_data(provider, line, current_event_state, handler_opts)
  print("Received line:", vim.inspect(line)) -- Debug print

  -- Handle OpenAI format
  if line:match("^data: ") then
    local data = line:match("^data: (.+)$")
    if data == "[DONE]" then
      handler_opts.on_complete(nil)
    else
      P[provider].parse_response(data, current_event_state, handler_opts)
    end
    return
  end

  -- Handle Anthropic format
  local event, data = line:match("^event:%s*(.-)%s*\ndata:%s*(.+)$")
  if event and data then
    local json_data = safe_json_decode(data)
    if json_data then
      P[provider].parse_response(json_data, event, handler_opts)
    else
      print("Failed to parse JSON data:", vim.inspect(data))
    end
    return
  end

  print("Unhandled line format:", vim.inspect(line))
end

M.stream = function(system_prompt, prompt, on_chunk, on_complete)
  local provider = Config.config.provider
  local code_opts = {
    base_prompt = prompt,
    system_prompt = system_prompt,
  }

  local current_event_state = nil
  local Provider = P[provider]

  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete }
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts)

  if active_job then
    active_job:shutdown()
    active_job = nil
  end

  active_job = curl.post(spec.url, {
    headers = spec.headers,
    proxy = spec.proxy,
    insecure = spec.insecure,
    body = vim.json.encode(spec.body),
    stream = function(err, data, _)
      if err then
        print("Stream error:", vim.inspect(err))
        on_complete(err)
        return
      end
      if not data then
        return
      end
      print("Raw data received in http.lua:", vim.inspect(data)) -- Debug print
      vim.schedule(function()
        -- Split the data into lines and process each line
        for line in data:gmatch("[^\r\n]+") do
          parse_stream_data(provider, line, current_event_state, handler_opts)
        end
      end)
    end,
    on_error = function(err)
      print("http error", vim.inspect(err))
      on_complete(err)
    end,
    callback = function(_)
      active_job = nil
      print("Stream completed")
    end,
  })

  api.nvim_create_autocmd("User", {
    group = group,
    pattern = M.CANCEL_PATTERN,
    callback = function()
      if active_job then
        active_job:shutdown()
        Utils.debug("LLM request cancelled", { title = "NVIM.AI" })
        active_job = nil
      end
    end,
  })

  return active_job
end

return M
