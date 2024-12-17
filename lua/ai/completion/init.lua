-- Completion source for blink.cmp
local M = {}
local config = require("ai.config")
local scan = require("plenary.scandir")
local utils = require("ai.utils")
local function get_buffers()
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name ~= "" then
        table.insert(buffers, {
          label = buf_name,
          bufnr = buf,
          kind = "buffer",
        })
      end
    end
  end
  return buffers
end
local function get_files()
  local files = {}
  local cwd = vim.fn.getcwd()
  scan.scan_dir(cwd, {
    hidden = true,
    respect_gitignore = true,
    add_dirs = false,
    on_insert = function(file)
      local relative_path = vim.fn.fnamemodify(file, ":.")
      table.insert(files, {
        label = relative_path,
        file_path = file,
        kind = "file",
      })
    end,
  })
  return files
end
local function get_directories()
  local directories = {}
  local cwd = vim.fn.getcwd()
  scan.scan_dir(cwd, {
    hidden = true,
    respect_gitignore = true,
    add_dirs = true,
    on_insert = function(dir)
      local relative_path = vim.fn.fnamemodify(dir, ":.")
      if vim.fn.isdirectory(dir) == 1 then
        table.insert(directories, {
          label = relative_path,
          dir_path = dir,
          kind = "directory",
        })
      end
    end,
  })
  return directories
end
M.new = function()
  return {
    name = "nvim-ai",
    priority = 100,
    -- This is the function that will be called when the user types something
    fetch = function(params)
      local line = params.line
      local before_cursor = line:sub(1, params.col - 1)
      local trigger = before_cursor:match("(/%w+)$")
      if not trigger then
        return nil
      end
      local items = {}
      if trigger == "/file" then
        items = get_files()
      elseif trigger == "/buf" then
        items = get_buffers()
      elseif trigger == "/dir" then
        items = get_directories()
      end
      return items
    end,
    -- This is the function that will be called when the user selects an item
    on_resolve = function(params, item)
      local line = params.line
      local before_cursor = line:sub(1, params.col - 1)
      local trigger = before_cursor:match("(/%w+)$")
      local replacement = ""
      if item.kind == "file" then
        replacement = "/file " .. item.label
      elseif item.kind == "buffer" then
        replacement = "/buf " .. item.bufnr
      elseif item.kind == "directory" then
        replacement = "/dir " .. item.label
      end
      return {
        text = replacement,
        -- Move the cursor to the end of the replacement
        cursor_pos = #replacement + 1,
      }
    end,
  }
end
return M
