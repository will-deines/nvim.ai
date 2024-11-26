local api = vim.api
local Utils = require("ai.utils")
local Config = require("ai.config")
local P = require("ai.providers")
local curl = require("plenary.curl")
local M = {}

M.CANCEL_PATTERN = "NVIMAIHTTPEscape"
local group = api.nvim_create_augroup("NVIMAIHTTP", { clear = true })
local active_job = nil

-- Function to create a temporary file with the request body
local function create_request_file(body)
  local tmp_dir = vim.fn.stdpath("cache") .. "/nvim-ai"
  vim.fn.mkdir(tmp_dir, "p")
  local tmp_file = tmp_dir .. "/request_" .. os.time() .. ".json"

  local file = io.open(tmp_file, "w")
  if file then
    file:write(vim.json.encode(body))
    file:close()
    return tmp_file
  end
  return nil
end

M.stream = function(system_prompt, prompt, on_chunk, on_complete)
  local provider = utils.state.selectedProvider
  local code_opts = {
    system_prompt = system_prompt,
    document = prompt.document,
    chat_history = prompt.chat_history,
  }
  local Provider = P[provider]
  local handler_opts = { on_chunk = on_chunk, on_complete = on_complete, current_event = nil }
  local spec = Provider.parse_curl_args(Config.get_provider(provider), code_opts)

  if active_job then
    active_job:shutdown()
    active_job = nil
  end

  local response_data = {}
  local function handle_response(data)
    if not data then
      return
    end
    if spec.stream then
      vim.schedule(function()
        P[provider].parse_response(data, true, handler_opts)
      end)
    else
      table.insert(response_data, data)
    end
  end

  -- Save request body to file if it's large
  local request_file = nil
  if #vim.json.encode(spec.body) > 1024 * 1024 then -- 1MB threshold
    request_file = create_request_file(spec.body)
    if not request_file then
      Utils.error("Failed to create request file")
      on_complete("Failed to create request file")
      return
    end
  end

  local curl_opts = {
    headers = spec.headers,
    proxy = spec.proxy,
    insecure = spec.insecure,
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
        local complete_json = table.concat(response_data)
        vim.schedule(function()
          P[provider].parse_response(complete_json, false, handler_opts)
        end)
      end
      -- Clean up temporary file if it exists
      if request_file then
        os.remove(request_file)
      end
      active_job = nil
    end,
  }

  -- Use file-based request if available
  if request_file then
    curl_opts.body_file = request_file
  else
    curl_opts.body = vim.json.encode(spec.body)
  end

  active_job = curl.post(spec.url, curl_opts)

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = M.CANCEL_PATTERN,
    callback = function()
      if active_job then
        active_job:shutdown()
        if request_file then
          os.remove(request_file)
        end
        Utils.debug("LLM request cancelled", { title = "NVIM.AI" })
        active_job = nil
      end
    end,
  })

  return active_job
end

return M
