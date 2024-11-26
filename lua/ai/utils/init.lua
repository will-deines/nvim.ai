local api = vim.api

local M = {}

M.state = {
  buf = nil,
  win = nil,
  last_saved_file = nil,
  current_model = nil,
  selectedProvider = nil,
  selectedModel = nil,
  loading = false,
  loading_timer = nil,
  spinner_line = nil,
}

setmetatable(M, {
  __index = function(t, k)
    local ok, lazyutil = pcall(require, "lazy.core.util")
    if ok and lazyutil[k] then
      return lazyutil[k]
    end

    ---@diagnostic disable-next-line: no-unknown
    t[k] = require("ai.utils." .. k)
    return t[k]
  end,
})

---Check if a plugin is installed
---@param plugin string
---@return boolean
M.has = function(plugin)
  return require("lazy.core.config").plugins[plugin] ~= nil
end

---@param str string
---@param opts? {suffix?: string, prefix?: string}
function M.trim(str, opts)
  if not opts then
    return str
  end
  if opts.suffix then
    return str:sub(-1) == opts.suffix and str:sub(1, -2) or str
  elseif opts.prefix then
    return str:sub(1, 1) == opts.prefix and str:sub(2) or str
  end
end

function M.in_visual_mode()
  local current_mode = vim.fn.mode()
  return current_mode == "v" or current_mode == "V" or current_mode == ""
end

---Wrapper around `api.nvim_buf_get_lines` which defaults to the current buffer
---@param start integer
---@param _end integer
---@param buf integer?
---@return string[]
function M.get_buf_lines(start, _end, buf)
  return api.nvim_buf_get_lines(buf or 0, start, _end, false)
end

---Get cursor row and column as (1, 0) based
---@param win_id integer?
---@return integer, integer
function M.get_cursor_pos(win_id)
  return unpack(api.nvim_win_get_cursor(win_id or 0))
end

---Check if the buffer is likely to have actionable conflict markers
---@param bufnr integer?
---@return boolean
function M.is_valid_buf(bufnr)
  bufnr = bufnr or 0
  return #vim.bo[bufnr].buftype == 0 and vim.bo[bufnr].modifiable
end

---@param name string?
---@return table<string, string>
function M.get_hl(name)
  if not name then
    return {}
  end
  return api.nvim_get_hl(0, { name = name })
end

--- vendor from lazy.nvim for early access and override

---@param msg string|string[]
---@param opts? LazyNotifyOpts
function M.notify(msg, opts)
  if vim.in_fast_event() then
    return vim.schedule(function()
      M.notify(msg, opts)
    end)
  end

  opts = opts or {}
  if type(msg) == "table" then
    ---@diagnostic disable-next-line: no-unknown
    msg = table.concat(
      vim.tbl_filter(function(line)
        return line or false
      end, msg),
      "\n"
    )
  end
  if opts.stacktrace then
    msg = msg .. M.pretty_trace({ level = opts.stacklevel or 2 })
  end
  local lang = opts.lang or "markdown"
  local n = opts.once and vim.notify_once or vim.notify
  n(msg, opts.level or vim.log.levels.INFO, {
    on_open = function(win)
      local ok = pcall(function()
        vim.treesitter.language.add("markdown")
      end)
      if not ok then
        pcall(require, "nvim-treesitter")
      end
      vim.wo[win].conceallevel = 3
      vim.wo[win].concealcursor = ""
      vim.wo[win].spell = false
      local buf = api.nvim_win_get_buf(win)
      if not pcall(vim.treesitter.start, buf, lang) then
        vim.bo[buf].filetype = lang
        vim.bo[buf].syntax = lang
      end
    end,
    title = opts.title or "lazy.nvim",
  })
end

---@param msg string|string[]
---@param opts? LazyNotifyOpts
function M.error(msg, opts)
  opts = opts or {}
  opts.level = vim.log.levels.ERROR
  M.notify(msg, opts)
end

---@param msg string|string[]
---@param opts? LazyNotifyOpts
function M.info(msg, opts)
  opts = opts or {}
  opts.level = vim.log.levels.INFO
  M.notify(msg, opts)
end

---@param msg string|string[]
---@param opts? LazyNotifyOpts
function M.warn(msg, opts)
  opts = opts or {}
  opts.level = vim.log.levels.WARN
  M.notify(msg, opts)
end

---@param msg string|table
---@param opts? LazyNotifyOpts
function M.debug(msg, opts)
  if not require("ai.config").config.debug then
    return
  end
  opts = opts or {}
  if opts.title then
    opts.title = "lazy.nvim: " .. opts.title
  end
  if type(msg) == "string" then
    M.notify(msg, opts)
  else
    opts.lang = "lua"
    M.notify(vim.inspect(msg), opts)
  end
end

function M.tbl_indexof(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      return i
    end
  end
  return nil
end

function M.update_win_options(winid, opt_name, key, value)
  local cur_opt_value = api.nvim_get_option_value(opt_name, { win = winid })

  if cur_opt_value:find(key .. ":") then
    cur_opt_value = cur_opt_value:gsub(key .. ":[^,]*", key .. ":" .. value)
  else
    if #cur_opt_value > 0 then
      cur_opt_value = cur_opt_value .. ","
    end
    cur_opt_value = cur_opt_value .. key .. ":" .. value
  end

  api.nvim_set_option_value(opt_name, cur_opt_value, { win = winid })
end

function M.get_win_options(winid, opt_name, key)
  local cur_opt_value = api.nvim_get_option_value(opt_name, { win = winid })
  if not cur_opt_value then
    return
  end
  local pieces = vim.split(cur_opt_value, ",")
  for _, piece in ipairs(pieces) do
    local kv_pair = vim.split(piece, ":")
    if kv_pair[1] == key then
      return kv_pair[2]
    end
  end
end

function M.unlock_buf(bufnr)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = true
end

function M.lock_buf(bufnr)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = false
end

---@param winnr? number
---@return nil
M.scroll_to_end = function(winnr)
  winnr = winnr or 0
  local bufnr = api.nvim_win_get_buf(winnr)
  local lnum = api.nvim_buf_line_count(bufnr)
  local last_line = api.nvim_buf_get_lines(bufnr, -2, -1, true)[1]
  api.nvim_win_set_cursor(winnr, { lnum, api.nvim_strwidth(last_line) })
end

---@param bufnr nil|integer
---@return nil
M.buf_scroll_to_end = function(bufnr)
  for _, winnr in ipairs(M.buf_list_wins(bufnr or 0)) do
    M.scroll_to_end(winnr)
  end
end

---@param bufnr nil|integer
---@return integer[]
M.buf_list_wins = function(bufnr)
  local wins = {}

  if not bufnr or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  for _, winnr in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(winnr) and api.nvim_win_get_buf(winnr) == bufnr then
      table.insert(wins, winnr)
    end
  end

  return wins
end

M.remove_spinner = function(buf_id)
  if M.state.spinner_line and vim.api.nvim_buf_is_valid(buf_id) then
    vim.api.nvim_buf_set_lines(buf_id, M.state.spinner_line - 1, M.state.spinner_line, false, {})
    M.state.spinner_line = nil
  end
end

M.start_loading = function(win_id, buf_id)
  if M.state.loading_timer then
    return
  end
  local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local prefix = "⌛ Waiting for response "
  local cancel_key = require("ai.chat_dialog").config.keymaps.cancel
  local suffix = string.format(" ... (Press %s to cancel)", cancel_key)
  local i = 1
  M.state.loading = true
  M.state.loading_timer = vim.uv.new_timer()
  if M.state.loading_timer then
    -- Add empty line before spinner
    vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, { "" })
    M.state.spinner_line = vim.api.nvim_buf_line_count(buf_id)
    vim.api.nvim_buf_set_lines(
      buf_id,
      M.state.spinner_line - 1,
      M.state.spinner_line,
      false,
      { prefix .. frames[i] .. suffix }
    )

    M.state.loading_timer:start(
      0,
      100,
      vim.schedule_wrap(function()
        if not (vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_buf_is_valid(buf_id)) then
          M.stop_loading()
          return
        end
        if M.state.loading then
          vim.api.nvim_buf_set_lines(
            buf_id,
            M.state.spinner_line - 1,
            M.state.spinner_line,
            false,
            { prefix .. frames[i] .. suffix }
          )
          i = (i % #frames) + 1
        end
      end)
    )
  end
end

M.stop_loading = function()
  if M.state.loading_timer then
    M.state.loading_timer:stop()
    M.state.loading_timer:close()
    M.state.loading_timer = nil
    M.state.loading = false
    M.remove_spinner(M.state.buf)
  end
end

return M
