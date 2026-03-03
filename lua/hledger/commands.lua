local M = {}

--- Get the hledger_lsp client for the current buffer.
---@return vim.lsp.Client|nil
local function get_client()
  local clients = vim.lsp.get_clients({ bufnr = 0, name = "hledger_lsp" })
  return clients[1]
end

--- Get a nested settings value by dot-separated key path.
---@param settings table
---@param key string e.g. "inlayHints.showInferredAmounts"
---@return any
local function get_setting(settings, key)
  local current = settings
  for part in key:gmatch("[^.]+") do
    if type(current) ~= "table" then return nil end
    current = current[part]
  end
  return current
end

--- Set a nested settings value by dot-separated key path.
---@param settings table
---@param key string
---@param value any
local function set_setting(settings, key, value)
  local parts = {}
  for part in key:gmatch("[^.]+") do
    table.insert(parts, part)
  end
  local current = settings
  for i = 1, #parts - 1 do
    if current[parts[i]] == nil then
      current[parts[i]] = {}
    end
    current = current[parts[i]]
  end
  current[parts[#parts]] = value
end

--- Send updated settings to the LSP server.
---@param client vim.lsp.Client
local function notify_settings_changed(client)
  client.notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

--- Toggle a set of boolean settings and notify the server.
---@param keys string[] dot-separated setting paths under hledgerLanguageServer
---@param label string human-readable label for the notification
local function toggle_settings(keys, label)
  local client = get_client()
  if not client then
    vim.notify("hledger-lsp not attached", vim.log.levels.WARN)
    return
  end

  local settings = client.config.settings or {}
  local hls = settings.hledgerLanguageServer or {}

  -- Check if any setting is currently enabled
  local any_enabled = false
  for _, key in ipairs(keys) do
    if get_setting(hls, key) ~= false then
      any_enabled = true
      break
    end
  end

  -- Toggle: if any are on, turn all off; otherwise turn all on
  local enable = not any_enabled
  for _, key in ipairs(keys) do
    set_setting(hls, key, enable)
  end

  settings.hledgerLanguageServer = hls
  client.config.settings = settings
  notify_settings_changed(client)

  vim.notify(
    string.format("hledger %s %s", label, enable and "enabled" or "disabled"),
    vim.log.levels.INFO
  )
end

function M.toggle_inlay_hints()
  -- Use Neovim's built-in inlay hint toggle (client-side, instant)
  if vim.lsp.inlay_hint then
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
    vim.notify(
      string.format("hledger inlay hints %s", enabled and "disabled" or "enabled"),
      vim.log.levels.INFO
    )
  else
    vim.notify("Inlay hints require Neovim 0.10+", vim.log.levels.WARN)
  end
end

function M.toggle_code_lens()
  toggle_settings({
    "codeLens.showTransactionCounts",
  }, "code lens")
end

function M.toggle_validation()
  toggle_settings({
    "validation.balance",
    "validation.missingAmounts",
    "validation.undeclaredAccounts",
    "validation.undeclaredPayees",
    "validation.undeclaredCommodities",
    "validation.undeclaredTags",
    "validation.dateOrdering",
    "validation.balanceAssertions",
    "validation.emptyTransactions",
    "validation.invalidDates",
    "validation.futureDates",
    "validation.emptyDescriptions",
    "validation.includeFiles",
    "validation.circularIncludes",
  }, "validation")
end

--- Get server status information for statusline integration.
---@return { attached: boolean, root: string|nil, files: number|nil }
function M.status()
  local client = get_client()
  if not client then
    return { attached = false }
  end
  return {
    attached = true,
    root = client.config.root_dir,
  }
end

--- Return a formatted statusline string.
---@return string
function M.statusline()
  local s = M.status()
  if not s.attached then
    return ""
  end
  return "hledger-lsp"
end

-- Expose for testing
M._get_setting = get_setting
M._set_setting = set_setting

return M
