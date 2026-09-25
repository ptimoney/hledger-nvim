local M = {}
local utils = require("hledger.utils")
local graph = require("hledger.graph")

function M.show_workspace_graph()
  local params = {
    command = "hledger.showWorkspaceGraphStructured",
    arguments = {},
  }
  
  -- Target hledger_lsp only: buf_request broadcasts to every attached client,
  -- and any other server rejects the command with "Unknown command".
  local client = vim.lsp.get_clients({ bufnr = 0, name = "hledger_lsp" })[1]
  if not client then
    vim.notify("hledger_lsp is not attached to this buffer", vim.log.levels.WARN)
    return
  end

  client:request("workspace/executeCommand", params, function(err, result, ctx, config)
    if err then
      vim.notify("Error getting workspace graph: " .. err.message, vim.log.levels.ERROR)
      return
    end
    if not result or #result == 0 then
      vim.notify("No graph data returned", vim.log.levels.WARN)
      return
    end

    -- Filter out cycle entries (entries without paths)
    local entries, lines, original_line_to_path = graph.filter_entries(result)

    if #entries == 0 then
      vim.notify("No files found in workspace graph", vim.log.levels.WARN)
      return
    end

    -- Calculate window dimensions
    local total_width = math.floor(vim.o.columns * utils.WINDOW_WIDTH_PERCENT)
    local max_height = math.floor(vim.o.lines * utils.WINDOW_HEIGHT_PERCENT)
    local content_height = math.min(#lines + 2, max_height - utils.RESERVED_PROMPT_LINES)
    local list_width = math.floor(total_width * utils.LIST_WIDTH_PERCENT)
    local preview_width = total_width - list_width - 2
    local col = math.floor((vim.o.columns - total_width) / 2)
    local row = math.floor((vim.o.lines - (content_height + utils.RESERVED_PROMPT_LINES)) / 2)

    -- Create main buffer (file list)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
    vim.api.nvim_set_option_value("filetype", "hledger-workspace", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    -- Create main window
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = list_width,
      height = content_height,
      col = col,
      row = row,
      style = "minimal",
      border = "rounded",
      title = " Hledger Workspace (za: fold, q: quit) ",
      title_pos = "center",
    })

    utils.set_win_options(win, {
      cursorline = true,
      number = false,
      relativenumber = false,
    })
    
    -- Create preview buffer and window
    local preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = preview_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = preview_buf })
    
    local preview_win = vim.api.nvim_open_win(preview_buf, false, {
      relative = "editor",
      width = preview_width,
      height = content_height,
      col = col + list_width + 2,
      row = row,
      style = "minimal",
      border = "rounded",
      title = " Preview ",
      title_pos = "center",
    })
    
    utils.set_win_options(preview_win, {
      number = true,
      relativenumber = false,
      wrap = false,
    })

    -- Create prompt buffer and window
    local prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "prompt", { buf = prompt_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prompt_buf })
    vim.fn.prompt_setprompt(prompt_buf, "Filter: ")

    local prompt_win = vim.api.nvim_open_win(prompt_buf, false, {
      relative = "editor",
      width = total_width,
      height = 1,
      col = col,
      row = row + content_height + 2,
      style = "minimal",
      border = "rounded",
      title = " Filter (Press /) ",
      title_pos = "center",
    })

    -- Track autocmd group for cleanup
    local group = vim.api.nvim_create_augroup("HledgerGraphFilter", { clear = true })
    
    -- Current line-to-path mapping (changes with filtering)
    local line_to_path = vim.deepcopy(original_line_to_path)
    
    -- Function to update preview window
    local function update_preview()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local path = line_to_path[line]
      
      vim.api.nvim_set_option_value("modifiable", true, { buf = preview_buf })
      
      if path then
        local stat = vim.loop.fs_stat(path)
        if stat and stat.type == "file" then
          local file = io.open(path, "r")
          if file then
            local content = {}
            for _ = 1, utils.PREVIEW_MAX_LINES do
              local l = file:read("*l")
              if not l then break end
              table.insert(content, l)
            end
            file:close()
            
            vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, content)
            
            local ft = utils.detect_filetype(path)
            if ft then
              vim.api.nvim_set_option_value("filetype", ft, { buf = preview_buf })
            end
          else
            vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "Error reading file" })
          end
        elseif stat and stat.type == "directory" then
          vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "Directory: " .. path })
        else
          vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "File not found" })
        end
      else
        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "" })
      end
      
      vim.api.nvim_set_option_value("modifiable", false, { buf = preview_buf })
    end
    
    -- Update preview on cursor move
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = group,
      buffer = buf,
      callback = update_preview,
    })
    
    -- Initial preview update
    update_preview()
    
    -- Pre-calculate depths and parent map (expensive, do once)
    local depths = graph.build_depths(lines)
    local parent_map = graph.build_parent_map(depths)

    -- Track folded nodes and display mapping
    local folded = {}
    local display_line_to_original = {}

    -- Namespace for highlighting
    local ns_id = vim.api.nvim_create_namespace("hledger_filter")

    -- Update display based on search filter and fold state
    local function update_display(search)
      vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

      local filtered, filtered_mapping, d2o, matches =
        graph.compute_display(lines, depths, parent_map, folded, search, original_line_to_path)

      display_line_to_original = d2o

      -- Update buffer
      vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, filtered)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

      -- Highlight matched characters and grey out non-matches
      if search ~= "" then
        for display_line = 1, #filtered do
          local original_index = display_line_to_original[display_line]
          if original_index then
            local match_positions = matches[original_index]
            if type(match_positions) == "table" and #match_positions > 0 then
              for _, pos in ipairs(match_positions) do
                vim.api.nvim_buf_add_highlight(buf, ns_id, "IncSearch", display_line - 1,
                  pos + utils.FOLD_INDICATOR_WIDTH, pos + utils.FOLD_INDICATOR_WIDTH + 1)
              end
            elseif not matches[original_index] then
              vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", display_line - 1, 0, -1)
            end
          end
        end
      end

      -- Update mapping for filtered results
      line_to_path = filtered_mapping
    end

    -- Initialize display
    update_display("")

    -- Helper to close all windows
    local function close_all_windows()
      pcall(vim.api.nvim_win_close, prompt_win, true)
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_win_close, preview_win, true)
      vim.api.nvim_clear_autocmds({ group = group })
    end

    -- Helper to open selected file
    local function open_file()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local path = line_to_path[line]
      if path then
        close_all_windows()
        vim.cmd("edit " .. vim.fn.fnameescape(path))
      end
    end

    -- Main window keymaps
    local opts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "<CR>", open_file, opts)
    vim.keymap.set("n", "q", close_all_windows, opts)
    vim.keymap.set("n", "<Esc>", close_all_windows, opts)

    -- Switch to prompt window with /
    vim.keymap.set("n", "/", function()
      vim.api.nvim_set_current_win(prompt_win)
      vim.cmd("startinsert")
    end, opts)

    -- Toggle fold with za
    vim.keymap.set("n", "za", function()
      local display_line = vim.api.nvim_win_get_cursor(win)[1]
      local original_idx = display_line_to_original[display_line]

      if original_idx and graph.has_children(original_idx, depths) then
        folded[original_idx] = not folded[original_idx]

        -- Get current search from prompt
        local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
        local search = (prompt_lines[1] or ""):gsub("^Filter: ", "")

        update_display(search)
        
        -- Restore cursor to the folded node's new display line
        for new_display_line, orig_idx in pairs(display_line_to_original) do
          if orig_idx == original_idx then
            vim.api.nvim_win_set_cursor(win, {new_display_line, 0})
            break
          end
        end
        
        update_preview()
      end
    end, opts)

    -- Apply filter on text change
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      group = group,
      buffer = prompt_buf,
      callback = function()
        local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
        local search = (prompt_lines[1] or ""):gsub("^Filter: ", "")
        update_display(search)
        update_preview()
      end,
    })

    -- Prompt buffer keymaps
    local prompt_opts = { buffer = prompt_buf, nowait = true, silent = true }

    -- Escape switches back to main window
    vim.keymap.set({ "n", "i" }, "<Esc>", function()
      vim.api.nvim_set_current_win(win)
    end, prompt_opts)

    -- Enter switches back to main window
    vim.keymap.set({ "i" }, "<CR>", function()
      vim.schedule(function()
        vim.api.nvim_set_current_win(win)
      end)
      return ""
    end, vim.tbl_extend("force", prompt_opts, { expr = true }))

    -- Ctrl-c closes all windows
    vim.keymap.set({ "n", "i" }, "<C-c>", close_all_windows, prompt_opts)
  end)
end

return M
