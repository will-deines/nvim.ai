local M = {}

local function identify_code_blocks_after_assistant()
  -- Get the current buffer and cursor position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor_pos[1]
  -- Initialize variables to store code blocks
  local code_blocks = {}
  local in_code_block = false
  local current_code_block = {}
  -- Scan backwards from the current line
  for line_num = current_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    -- Check for the start of the assistant's response
    if line:match("^/assistant:") then
      break
    end
    -- Check for code block delimiters (triple backticks)
    if line:match("^```") then
      if in_code_block then
        -- End of a code block
        in_code_block = false
        table.insert(code_blocks, { start = line_num, lines = current_code_block })
        current_code_block = {}
      else
        -- Start of a code block
        in_code_block = true
      end
    elseif in_code_block then
      -- Collect lines within a code block
      table.insert(current_code_block, 1, line_num)
    end
  end
  -- Handle any remaining code block that wasn't closed
  if in_code_block and #current_code_block > 0 then
    table.insert(code_blocks, { start = current_code_block[1], lines = current_code_block })
  end
  -- Return the identified code blocks
  return code_blocks
end

local function highlight_code_blocks(code_blocks)
  for i, block in ipairs(code_blocks) do
    for _, line_num in ipairs(block.lines) do
      vim.api.nvim_buf_add_highlight(0, -1, "Visual", line_num - 1, 0, -1)
    end
  end
end

local function navigate_code_blocks(code_blocks)
  local current_index = 1
  local function move_to_next_block()
    if current_index > #code_blocks then
      current_index = 1
    end
    local block = code_blocks[current_index]
    vim.api.nvim_win_set_cursor(0, { block.start, 0 })
    current_index = current_index + 1
  end
  vim.api.nvim_set_keymap("n", "n", ":lua move_to_next_block()<CR>", { noremap = true, silent = true })
end

local function yank_and_exit()
  vim.api.nvim_command("normal! V")
  vim.api.nvim_command("normal! y")
  vim.api.nvim_command("normal! :noh<CR>")
  vim.api.nvim_del_keymap("n", "n")
end

function M.identify_and_navigate_code_blocks()
  local code_blocks = identify_code_blocks_after_assistant()
  highlight_code_blocks(code_blocks)
  navigate_code_blocks(code_blocks)
  vim.api.nvim_set_keymap("n", "y", ":lua yank_and_exit()<CR>", { noremap = true, silent = true })
end

vim.api.nvim_set_keymap(
  "n",
  "<leader>cb",
  ':lua require("ai.code_block_navigator").identify_and_navigate_code_blocks()<CR>',
  { noremap = true, silent = true }
)

return M
