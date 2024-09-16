local api = vim.api
local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local curl = require("plenary.curl")
local M = {}

M.CANCEL_PATTERN = "NVIMAIHTTPEscape"
local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

-- Function to parse streamed data from the provider
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
      Utils.warn("Failed to decode JSON from data: " .. tostring(data))
    end
  else
    Utils.debug("Unhandled line format: " .. vim.inspect(line), { title = "NVIM.AI HTTP Debug" })
  end
end

-- Stream function to interact with AI providers
M.stream = function(system_prompt, prompt, on_chunk, on_complete, model)
  local provider = Config.config.provider
  local code_opts = {
    base_prompt = prompt,
    system_prompt = system_prompt,
  }
  local Provider = P[provider]
  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete, current_event = nil }
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts, model)

  -- Debug: Log the API call details
  if Config.config.debug then
    Utils.debug("API Request Details:", {
      title = "NVIM.AI HTTP Debug",
      url = spec.url,
      headers = spec.headers,
      body = spec.body,
      proxy = spec.proxy,
      insecure = spec.insecure,
      stream = spec.stream,
    })
  end

  -- Shutdown any existing active job before starting a new one
  if active_job then
    active_job:shutdown()
    active_job = nil
  end

  -- Function to handle the response data
  local function handle_response(data)
    if not data then
      return
    end
    vim.schedule(function()
      if spec.stream then
        for line in data:gmatch("[^\r\n]+") do
          parse_stream_data(provider, line, handler_opts)
        end
      else
        local success, json = pcall(vim.json.decode, data)
        if success then
          P[provider].parse_response(json, nil, handler_opts)
        else
          Utils.warn("Failed to decode JSON from data: " .. tostring(data))
        end
      end

      -- Debug: Log the full response data if not streaming
      if not spec.stream and Config.config.debug then
        Utils.debug("API Response Data:", {
          title = "NVIM.AI HTTP Debug",
          response = json,
        })
      end
    end)
  end

  -- Initiate the HTTP POST request using plenary.curl
  active_job = curl.post(spec.url, {
    headers = spec.headers,
    proxy = spec.proxy,
    insecure = spec.insecure,
    body = vim.json.encode(spec.body),
    stream = spec.stream
        and function(err, data)
          if err then
            Utils.error("Stream error: " .. vim.inspect(err), { title = "NVIM.AI HTTP Error" })
            on_complete(err)
            return
          end

          -- Debug: Log each chunk of data received in streaming mode
          if Config.config.debug then
            Utils.debug("Received Stream Chunk:", {
              title = "NVIM.AI HTTP Debug",
              chunk = data,
            })
          end

          handle_response(data)
        end
      or nil,
    on_error = function(err)
      Utils.error("HTTP error: " .. vim.inspect(err), { title = "NVIM.AI HTTP Error" })
      on_complete(err)
    end,
    callback = function(response)
      if not spec.stream then
        handle_response(response.body)

        -- Debug: Log the complete response for non-streaming requests
        if Config.config.debug then
          Utils.debug("Complete API Response:", {
            title = "NVIM.AI HTTP Debug",
            response = response.body,
          })
        end
      end
      active_job = nil
    end,
  })

  -- Create an autocmd to handle cancellation of the request
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = M.CANCEL_PATTERN,
    callback = function()
      if active_job then
        active_job:shutdown()

        -- Debug: Notify that the request has been cancelled
        Utils.debug("LLM request cancelled", { title = "NVIM.AI HTTP Debug" })
        active_job = nil
      end
    end,
  })

  return active_job
end

return M
