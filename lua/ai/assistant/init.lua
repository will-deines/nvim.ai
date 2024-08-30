local Providers = require("ai.providers")
local Config = require("ai.config")
local Http = require("ai.http")
local Assist = require("ai.assistant.assist")
local Inline = require("ai.assistant.inline")
local Prompts = require("ai.assistant.prompts")
local M = {}

M.ask = function(system_prompt, raw_prompt, on_chunk, on_complete, model)
  if system_prompt == nil then
    system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  end
  local provider = Config.config.provider
  local p = Providers.get(provider)
  local prompt = Assist.parse_chat_prompt(raw_prompt)
  Http.stream(system_prompt, prompt, on_chunk, on_complete, model)
end

M.inline = function(prompt)
  Inline:new(prompt)
end

M.accept_code = function()
  Inline:accept_code()
end

M.reject_code = function()
  Inline:reject_code()
end

return M
