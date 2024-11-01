local Http = require("ai.http")
local Assist = require("ai.assistant.assist")
local Prompts = require("ai.assistant.prompts")
local M = {}

M.ask = function(system_prompt, raw_prompt, on_chunk, on_complete, model)
  if system_prompt == nil then
    system_prompt = Prompts.GLOBAL_SYSTEM_PROMPT
  end
  local parsed_prompt = Assist.parse_chat_prompt(raw_prompt)
  Http.stream(system_prompt, parsed_prompt, on_chunk, on_complete, model)
end

return M
