local M = {}

local max_entries = 5
local walk_timeout_ms = 1500

local list = {}
local switching = false
local walk = nil

local function is_trackable(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == ""
    and vim.bo[buf].buflisted
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function push(buf)
  for i = #list, 1, -1 do
    if list[i] == buf then
      table.remove(list, i)
    end
  end
  table.insert(list, 1, buf)
  while #list > max_entries do
    table.remove(list)
  end
end

local function cycle(step)
  local now = vim.uv.now()
  local cur = vim.api.nvim_get_current_buf()
  if not (walk and now - walk.at < walk_timeout_ms and walk.targets[walk.idx] == cur) then
    local targets = { cur }
    for _, buf in ipairs(list) do
      if buf ~= cur and vim.api.nvim_buf_is_valid(buf) then
        targets[#targets + 1] = buf
      end
    end
    if #targets < 2 then
      return
    end
    walk = { targets = targets, idx = 1, at = now }
  end
  local n = #walk.targets
  walk.idx = ((walk.idx - 1 + step) % n) + 1
  walk.at = now
  switching = true
  vim.api.nvim_set_current_buf(walk.targets[walk.idx])
  switching = false
end

function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("Mru", { clear = true }),
    callback = function(args)
      if switching then
        return
      end
      if is_trackable(args.buf) then
        push(args.buf)
      end
    end,
  })
  vim.keymap.set("n", "<C-Tab>", function()
    cycle(1)
  end, { desc = "Next recent buffer" })
  vim.keymap.set("n", "<C-S-Tab>", function()
    cycle(-1)
  end, { desc = "Previous recent buffer" })
end

M._test = {
  cycle = cycle,
  list = function()
    return list
  end,
}

return M
