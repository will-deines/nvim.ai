local api = vim.api
local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local curl = require("plenary.curl")
local M = {}
M.CANCEL_PATTERN = "NVIMAIHTTPEscape"
local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

local function parse_stream_data(provider, line, handler_opts)
  local event, data
  if line:match("^event: ") then
    event = line:match("^event: (.+)$")
    handler_opts.current_event = event
  elseif line:match("^data: ") then
    data = line:match("^data: (.+)$")
    local success, json = pcall(vim.json.decode, data)
    if success then
      P[provider].parse_response(json, handler_opts.current_event, handler_opts)
    else
      print("Failed to decode JSON from data:", data)
    end
  else
    print("Unhandled line format:", vim.inspect(line))
  end
end

M.stream = function(system_prompt, prompt, on_chunk, on_complete, model)
  local provider = Config.config.provider
  local code_opts = {
    base_prompt = prompt,
    system_prompt = system_prompt,
  }
  local Provider = P[provider]
  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete, current_event = nil }
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts, model)

  -- Log the entire request
  Utils.debug("Full request details:", { title = "NVIM.AI HTTP Request" })
  Utils.debug("URL: " .. spec.url, { title = "NVIM.AI HTTP Request" })
  Utils.debug("Headers: " .. vim.inspect(spec.headers), { title = "NVIM.AI HTTP Request" })
  Utils.debug("Body: " .. vim.inspect(spec.body), { title = "NVIM.AI HTTP Request" })
  Utils.debug("Proxy: " .. tostring(spec.proxy), { title = "NVIM.AI HTTP Request" })
  Utils.debug("Insecure: " .. tostring(spec.insecure), { title = "NVIM.AI HTTP Request" })

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
        Utils.debug("Stream error: " .. vim.inspect(err), { title = "NVIM.AI HTTP Error" })
        on_complete(err)
        return
      end
      if not data then
        return
      end
      vim.schedule(function()
        for line in data:gmatch("[^\r\n]+") do
          parse_stream_data(provider, line, handler_opts)
        end
      end)
    end,
    on_error = function(err)
      Utils.debug("HTTP error: " .. vim.inspect(err), { title = "NVIM.AI HTTP Error" })
      on_complete(err)
    end,
    callback = function(_)
      active_job = nil
    end,
  })
  vim.api.nvim_create_autocmd("User", {
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
