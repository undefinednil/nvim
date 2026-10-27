-- Oil pinned to the left as a fixed-width sidebar (a window of its own,
-- unlike `-`, which turns the current window into an oil browser).
-- The sidebar opens by itself when nvim starts with a UI and never takes
-- focus on its own. <C-b> shows or hides it; <C-h> jumps into it; <C-l>
-- jumps back to the main window. While it is open it follows the file being
-- edited: the sidebar shows the file's directory with the cursor on the file
-- itself. <CR> on a file opens it in the main window so the sidebar stays
-- put. When the last real window of a tab closes, the sidebar closes too, so
-- `:q` stays a single quit.

local M = {}

local width = 30

local main_win -- most recently focused window that is not the sidebar
local pending -- { buf, name }: file to put the cursor on once its dir loads
local opening -- set while M.open builds the split, so WinEnter ignores it
local startup_opened -- the sidebar was opened once at startup

local function norm(path)
  return (path:gsub("/+$", ""))
end

local function sidebar_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.w[win].oil_sidebar then
      return win
    end
  end
end

-- In a CodeDiff tab the CodeDiff explorer panel already is the left sidebar.
-- The sidebar keys steer that panel there instead of opening oil next to it
-- (codediff_ctx returns the tabpage and the panel view; the panel view is nil
-- for bare diff tabs, which keep the plain sidebar behavior).
local function codediff_ctx()
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    return nil
  end
  local tabpage = vim.api.nvim_get_current_tabpage()
  if not lifecycle.get_session(tabpage) then
    return nil
  end
  return tabpage, lifecycle.get_panel_view(tabpage)
end

local function codediff_panel(action, tabpage)
  local ok, panes = pcall(require, "codediff.ui.view.actions.panes")
  if ok then
    panes[action]({ tabpage = tabpage })
  end
end

local function is_codediff_panel_win(win)
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype == "codediff-explorer"
end

local function file_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then
    return nil
  end
  return name
end

-- Directory and file name to show for a buffer path. A directory buffer
-- (netrw, `nvim .`) stands for itself.
local function locate(path)
  if vim.fn.isdirectory(path) == 1 then
    return path, nil
  end
  return vim.fn.fnamemodify(path, ":p:h"), vim.fn.fnamemodify(path, ":t")
end

local function place_cursor(win, name)
  if not name then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.b[buf].oil_ready then
    return
  end
  for lnum = 1, vim.api.nvim_buf_line_count(buf) do
    local entry = require("oil").get_entry_on_line(buf, lnum)
    if entry and entry.name == name then
      local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
      local col = (line:find(name, 1, true) or 1) - 1
      vim.api.nvim_win_set_cursor(win, { lnum, col })
      return
    end
  end
end

local function show(win, dir, name)
  vim.api.nvim_win_call(win, function()
    require("oil").open(dir)
  end)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.b[buf].oil_ready then
    place_cursor(win, name)
  else
    pending = { buf = buf, name = name }
  end
end

local function follow()
  local win = sidebar_win()
  if not win or vim.api.nvim_get_current_win() == win then
    return
  end
  local path = file_path(vim.api.nvim_get_current_buf())
  if not path then
    return
  end
  local dir, name = locate(path)
  local current = require("oil").get_current_dir(vim.api.nvim_win_get_buf(win))
  if current and norm(current) == norm(dir) then
    return
  end
  show(win, dir, name)
end

local function focus_with_file(win)
  local path = file_path(vim.api.nvim_get_current_buf())
  vim.api.nvim_set_current_win(win)
  if not path then
    return
  end
  local dir, name = locate(path)
  local current = require("oil").get_current_dir(vim.api.nvim_win_get_buf(win))
  if current and norm(current) == norm(dir) then
    place_cursor(win, name)
  end
end

local function set_win_options(win)
  vim.wo[win].winfixwidth = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  -- Oil keeps its own list of window options (conceallevel and friends); the
  -- window is created without entering its buffer, so apply them here too.
  for k, v in pairs(require("oil.config").win_options) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
  end
  vim.api.nvim_win_set_width(win, width)
end

function M.main_window()
  if main_win and vim.api.nvim_win_is_valid(main_win) and not vim.w[main_win].oil_sidebar then
    return main_win
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not vim.w[win].oil_sidebar then
      return win
    end
  end
end

---Open the sidebar next to the current window. Focus stays where it is
---unless opts.focus is set.
function M.open(opts)
  opts = opts or {}
  local origin = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local dir, name
  if vim.bo[buf].filetype == "oil" then
    dir = require("oil").get_current_dir(buf)
  else
    local path = file_path(buf)
    if path then
      dir, name = locate(path)
    end
  end
  main_win = origin
  opening = true
  vim.cmd("topleft vsplit")
  opening = false
  local win = vim.api.nvim_get_current_win()
  vim.w[win].oil_sidebar = true
  set_win_options(win)
  show(win, dir or vim.fn.getcwd(), name)
  if not opts.focus then
    vim.api.nvim_set_current_win(origin)
  end
end

function M.close()
  local win = sidebar_win()
  if not win then
    return
  end
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    vim.w[win].oil_sidebar = nil
    vim.cmd.enew()
    return
  end
  if vim.api.nvim_get_current_win() == win then
    local target = M.main_window()
    if target then
      vim.api.nvim_set_current_win(target)
    end
  end
  vim.api.nvim_win_close(win, true)
end

---Show or hide the sidebar. Focus does not move.
function M.toggle()
  local tabpage, panel = codediff_ctx()
  if panel then
    if sidebar_win() then
      M.close()
    else
      codediff_panel("toggle_explorer", tabpage)
    end
    return
  end
  if sidebar_win() then
    M.close()
  else
    M.open()
  end
end

---Jump to the sidebar, opening it focused if it is hidden.
function M.focus()
  local tabpage, panel = codediff_ctx()
  if panel then
    if sidebar_win() then
      M.close()
    end
    codediff_panel("focus_explorer", tabpage)
    return
  end
  local win = sidebar_win()
  if win then
    focus_with_file(win)
  else
    M.open({ focus = true })
  end
end

---Jump back to the main window.
function M.focus_main()
  if is_codediff_panel_win(vim.api.nvim_get_current_win()) then
    local tab = vim.api.nvim_get_current_tabpage()
    local target = M.main_window()
    if not (target and vim.api.nvim_win_get_tabpage(target) == tab) then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if not is_codediff_panel_win(win) then
          target = win
          break
        end
      end
    end
    if target and vim.api.nvim_win_get_tabpage(target) == tab and target ~= vim.api.nvim_get_current_win() then
      vim.api.nvim_set_current_win(target)
    end
    return
  end
  if not sidebar_win() then
    return
  end
  local target = M.main_window()
  if target and vim.api.nvim_get_current_win() ~= target then
    vim.api.nvim_set_current_win(target)
  end
end

-- Oil callback for <CR>. In the sidebar a file goes to the main window;
-- directories keep oil's default behavior (navigate inside the sidebar).
-- Returns true when it handled the selection.
function M.select_in_main_win()
  local win = sidebar_win()
  if not win or vim.api.nvim_get_current_win() ~= win then
    return false
  end
  local entry = require("oil").get_cursor_entry()
  if not entry or require("oil.util").is_directory(entry) then
    return false
  end
  local target = M.main_window()
  if not target then
    return false
  end
  require("oil.util").get_edit_path(vim.api.nvim_win_get_buf(win), entry, function(url)
    local file_buf = vim.fn.bufadd(url)
    vim.bo[file_buf].buflisted = true
    if not vim.api.nvim_win_is_valid(target) then
      return
    end
    vim.api.nvim_win_call(target, function()
      vim.cmd({ cmd = "buffer", args = { file_buf } })
    end)
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
      vim.api.nvim_set_current_win(target)
    end
  end)
  return true
end

local function open_on_start()
  if startup_opened then
    return
  end
  startup_opened = true
  -- Defer to the main loop: inside an autocmd context oil's buffer load
  -- (BufReadCmd) is suppressed and the sidebar would stay empty.
  vim.schedule(function()
    if not sidebar_win() then
      M.open()
    end
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("WinEnter", {
    callback = function()
      if opening then
        return
      end
      local win = vim.api.nvim_get_current_win()
      if not vim.w[win].oil_sidebar and not is_codediff_panel_win(win) then
        main_win = win
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(args)
      if vim.bo[args.buf].filetype == "oil" or not sidebar_win() then
        return
      end
      -- BufEnter can run while window changes are locked, so defer the
      -- sidebar update to the main loop.
      vim.schedule(follow)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = "OilEnter",
    callback = function(args)
      if not pending or pending.buf ~= args.data.buf then
        return
      end
      local p = pending
      pending = nil
      local win = sidebar_win()
      if win and vim.api.nvim_win_get_buf(win) == p.buf then
        place_cursor(win, p.name)
      end
    end,
  })
  -- When the last real window of a tab closes, do not leave the sidebar
  -- behind as the window that blocks `:q` from exiting nvim. The sidebar
  -- closes itself after the fact, so a failed quit never touches the layout.
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = function()
      vim.schedule(function()
        if vim.v.exiting ~= vim.NIL then
          return
        end
        local wins = vim.api.nvim_tabpage_list_wins(0)
        if #wins ~= 1 or not vim.w[wins[1]].oil_sidebar then
          return
        end
        if #vim.api.nvim_list_tabpages() > 1 then
          vim.cmd.tabclose()
          return
        end
        local ok = pcall(vim.cmd.quit)
        if not ok then
          -- A buffer somewhere still has unsaved changes; plain nvim would
          -- refuse this quit too. Say so instead of a lua stack trace.
          vim.api.nvim_echo({ { "Not quitting: a buffer has unsaved changes (use :qa! to force)", "WarningMsg" } }, true, {})
        end
      end)
    end,
  })
  -- Open at startup once a UI is attached: UIEnter when it arrives late
  -- (--embed clients), VimEnter for the built-in TUI. Headless stays clean.
  vim.api.nvim_create_autocmd("UIEnter", {
    callback = open_on_start,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      if #vim.api.nvim_list_uis() > 0 then
        open_on_start()
      end
    end,
  })
end

return M
