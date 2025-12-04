local M = {}

-- Constants for window sizing
M.WINDOW_WIDTH_PERCENT = 0.9
M.WINDOW_HEIGHT_PERCENT = 0.8
M.LIST_WIDTH_PERCENT = 0.4
M.RESERVED_PROMPT_LINES = 5
M.PREVIEW_MAX_LINES = 100
M.FOLD_INDICATOR_WIDTH = 4

-- Helper: Set multiple window options at once
function M.set_win_options(win, options)
  for key, value in pairs(options) do
    vim.api.nvim_win_set_option(win, key, value)
  end
end

-- Helper: Calculate depth from display string
function M.get_depth(display)
  local depth = 0
  
  -- Count leading spaces (groups of 4)
  local spaces = display:match("^( *)")
  depth = depth + math.floor(#spaces / 4)
  
  -- Count box drawing characters
  depth = depth + select(2, display:gsub("[│├└]", ""))
  
  return depth
end

-- Helper: Fuzzy matching - returns match result and character positions
function M.fuzzy_match(str, pattern)
  if pattern == "" then
    return true, {}
  end
  
  local pattern_idx = 1
  local str_idx = 1
  local pattern_len = #pattern
  local str_len = #str
  local positions = {}
  
  while pattern_idx <= pattern_len and str_idx <= str_len do
    if str:sub(str_idx, str_idx):lower() == pattern:sub(pattern_idx, pattern_idx):lower() then
      table.insert(positions, str_idx - 1) -- 0-indexed for nvim highlight
      pattern_idx = pattern_idx + 1
    end
    str_idx = str_idx + 1
  end
  
  return pattern_idx > pattern_len, positions
end

-- Helper: Detect filetype for preview
function M.detect_filetype(path)
  local ft = vim.filetype.match({ filename = path })
  if not ft and (path:match("%.journal$") or path:match("%.hledger$")) then
    ft = "hledger"
  end
  return ft
end

return M
