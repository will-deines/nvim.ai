local api = vim.api
local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local curl = require("plenary.curl")
local M = {}
M.CANCEL_PATTERN = "NVIMAIHTTPEscape"
local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

M.stream = function(system_prompt, prompt, on_chunk, on_complete, model)
  local provider = Config.config.provider
  local code_opts = {
    base_prompt = prompt,
    system_prompt = system_prompt,
  }
  local Provider = P[provider]
  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete, current_event = nil }
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts, model)

  if active_job then
    active_job:shutdown()
    active_job = nil
  end

  local function handle_response(data)
    if not data then
      return
    end
    vim.schedule(function()
      P[provider].parse_response(data, handler_opts.current_event, handler_opts)
    end)
  end

  active_job = curl.post(spec.url, {
    headers = spec.headers,
    proxy = spec.proxy,
    insecure = spec.insecure,
    body = vim.json.encode(spec.body),
    stream = spec.stream and function(err, data)
      if err then
        Utils.debug("Stream error: " .. vim.inspect(err), { title = "NVIM.AI HTTP Error" })
        on_complete(err)
        return
      end
      handle_response(data)
    end or nil,
    on_error = function(err)
      Utils.debug("HTTP error: " .. vim.inspect(err), { title = "NVIM.AI HTTP Error" })
      on_complete(err)
    end,
    callback = function(response)
      if not spec.stream then
        handle_response(response.body)
      end
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
