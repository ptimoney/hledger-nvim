--- Pure computation for workspace graph tree display.
--- Extracted from ui.lua so it can be unit-tested without Neovim UI APIs.
local M = {}

local utils = require("hledger.utils")

--- Build a depth table from display lines.
---@param lines string[]
---@return number[] depths (1-indexed, parallel to lines)
function M.build_depths(lines)
  local depths = {}
  for i, line in ipairs(lines) do
    depths[i] = utils.get_depth(line)
  end
  return depths
end

--- Build a parent map from a depth table.
--- parent_map[i] = j means line j is the parent of line i.
---@param depths number[]
---@return table<number, number>
function M.build_parent_map(depths)
  local parent_map = {}
  for i = 2, #depths do
    local my_depth = depths[i]
    for j = i - 1, 1, -1 do
      if depths[j] == my_depth - 1 then
        parent_map[i] = j
        break
      end
    end
  end
  return parent_map
end

--- Check if a line has children (the next line is deeper).
---@param line_idx number
---@param depths number[]
---@return boolean
function M.has_children(line_idx, depths)
  return line_idx < #depths and depths[line_idx + 1] > depths[line_idx]
end

--- Filter entries that have valid paths.
---@param entries table[] each with .path and .display fields
---@return table[] filtered_entries
---@return string[] lines (display strings)
---@return table<number, string> original_line_to_path
function M.filter_entries(entries)
  local filtered = {}
  local lines = {}
  local original_line_to_path = {}
  for _, entry in ipairs(entries) do
    if entry.path and entry.path ~= "" then
      table.insert(filtered, entry)
      table.insert(lines, entry.display)
      original_line_to_path[#lines] = entry.path
    end
  end
  return filtered, lines, original_line_to_path
end

--- Compute the display state: which lines to show, fold indicators, and match data.
---@param lines string[] original display lines
---@param depths number[] depth per line
---@param parent_map table<number, number> parent relationships
---@param folded table<number, boolean> folded state per original line
---@param search string current search/filter text ("" for no filter)
---@param original_line_to_path table<number, string> path per original line
---@return string[] display_lines lines to render (with fold indicators)
---@return table<number, string> line_to_path path mapping for display lines
---@return table<number, number> display_to_original maps display line -> original line
---@return table<number, table> matches maps original line -> match positions (only when search active)
function M.compute_display(lines, depths, parent_map, folded, search, original_line_to_path)
  local matches = {}
  local include = {}

  if search == "" then
    for i = 1, #lines do
      include[i] = true
    end
  else
    -- Find matching lines
    for i, line in ipairs(lines) do
      local is_match, positions = utils.fuzzy_match(line, search)
      if is_match then
        matches[i] = positions
      end
    end

    -- Include all ancestor nodes of matches
    for match_idx in pairs(matches) do
      include[match_idx] = true
      local current = match_idx
      while parent_map[current] do
        current = parent_map[current]
        include[current] = true
      end
    end
  end

  -- Filter out descendants of folded nodes
  for i = 1, #lines do
    if include[i] then
      local current = i
      while parent_map[current] do
        current = parent_map[current]
        if folded[current] then
          include[i] = false
          break
        end
      end
    end
  end

  -- Build display list with fold indicators
  local display_lines = {}
  local line_to_path = {}
  local display_to_original = {}
  for i, line in ipairs(lines) do
    if include[i] then
      local display_line
      if M.has_children(i, depths) then
        display_line = (folded[i] and "▶ " or "▼ ") .. line
      else
        display_line = "  " .. line
      end
      table.insert(display_lines, display_line)
      line_to_path[#display_lines] = original_line_to_path[i]
      display_to_original[#display_lines] = i
    end
  end

  return display_lines, line_to_path, display_to_original, matches
end

return M
