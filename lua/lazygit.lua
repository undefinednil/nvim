-- Toggle lazygit in a floating terminal window.
--
-- `:!lazygit` cannot work: bang commands run without a controlling terminal,
-- so lazygit fails with "open /dev/tty: device not configured". A terminal
-- job (`jobstart` with term=true) gets a pty, which is what TUIs need.

local M = {}

local state = {}

local function close()
  local buf, win, job = state.buf, state.win, state.job
  state.buf, state.win, state.job = nil, nil, nil
  if job then
    pcall(vim.fn.jobstop, job)
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

local function geometry()
  return {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines - vim.o.cmdheight,
    style = "minimal",
  }
end

local function toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close()
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, geometry())
  -- Default terminal fg/bg follow the window's Normal; point it at the kitty
  -- (One Half Dark) colors so lazygit looks like it does in a plain terminal.
  vim.wo[win].winhighlight = "Normal:LazygitTerminal"
  state.buf, state.win = buf, win
  state.job = vim.fn.jobstart({ "lazygit" }, { term = true })
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = buf,
    once = true,
    callback = function()
      if state.buf == buf then
        close()
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if state.win == win then
        close()
      end
    end,
  })
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Close lazygit" })
  vim.cmd.startinsert()
end

function M.setup()
  vim.api.nvim_set_hl(0, "LazygitTerminal", { fg = "#dcdfe4", bg = "#282c34" })
  vim.keymap.set("n", "<leader>lz", toggle, { desc = "Toggle lazygit" })
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_config(state.win, geometry())
      end
    end,
  })
end

M._test = {
  toggle = toggle,
  state = state,
}

return M
