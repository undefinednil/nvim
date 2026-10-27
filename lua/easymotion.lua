-- EasyMotion-style jumps with labels, a clone of VSCodeVim's easymotion.
-- s / S: jump to the next/previous word: the start of a run of keyword
-- characters (punctuation like '.' is not a target, and it never stops
-- inside a word). <leader><leader>f / F: subword jumps
-- (camelCase, snake_case, acronym and digit boundaries), landing on the
-- subword start. <leader><leader>t / T: the same subword targets, but
-- landing one character before/after, like t/T. All motions also work in
-- operator-pending mode (d/y/c) and extend the jump through the landing
-- character, the way d<leader><leader>f behaves in VSCodeVim.
-- Labels, narrowing, and the dimmed background follow the VSCode settings:
-- label key order, marker colors. The search covers only the visible lines,
-- so the single-letter labels are not starved on large files.

local M = {}

local defaults = {
  keys = "hklyuiopnmqwertzxcvbasdgjf",
  one_char_color = "#fcc77c",
  two_char_first_color = "#bfcff0",
  two_char_second_color = "#99bbdd",
  dim_background = true,
  dim_color = "#777777",
  bold = true,
  max_matches = 1000,
}

local config = vim.deepcopy(defaults)

local ns = vim.api.nvim_create_namespace("easymotion")

local hl = {
  one = "EasyMotionOneChar",
  two_first = "EasyMotionTwoCharFirst",
  two_second = "EasyMotionTwoCharSecond",
  dim = "EasyMotionDim",
}

local function define_highlights()
  vim.api.nvim_set_hl(0, hl.one, { fg = config.one_char_color, bold = config.bold })
  vim.api.nvim_set_hl(0, hl.two_first, { fg = config.two_char_first_color, bold = config.bold })
  vim.api.nvim_set_hl(0, hl.two_second, { fg = config.two_char_second_color, bold = config.bold })
  vim.api.nvim_set_hl(0, hl.dim, { fg = config.dim_color })
end

local function clear_marks(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

-- Subword starts inside a \w run, spider style: after '_', at camelCase
-- humps, before the last capital of an acronym run (HTTP|Server), and at
-- letter/digit boundaries (version|2|Test). '_' itself never gets a label.
local function is_subword_start(line, i, run_start)
  -- i and run_start are 0-based byte offsets; string.byte is 1-based.
  local c = line:byte(i + 1)
  if c == 95 then
    return false
  end
  if i == run_start then
    return true
  end
  local p = line:byte(i)
  local n = line:byte(i + 2)
  if p == 95 then
    return true
  end
  local p_lower = p >= 97 and p <= 122
  local p_upper = p >= 65 and p <= 90
  local p_digit = p >= 48 and p <= 57
  local c_upper = c >= 65 and c <= 90
  local c_lower = c >= 97 and c <= 122
  local c_digit = c >= 48 and c <= 57
  if p_lower and c_upper then
    return true
  end
  if p_upper and c_upper and n and n >= 97 and n <= 122 then
    return true
  end
  if (p_lower or p_upper) and c_digit then
    return true
  end
  if p_digit and (c_lower or c_upper) then
    return true
  end
  return false
end

-- Subword starts on the visible lines, capped at max_matches.
local function collect_subwords(buf, cur, direction)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local first = math.max(0, vim.fn.line("w0") - 1)
  local last = math.min(vim.fn.line("w$") - 1, line_count - 1)
  local re = vim.regex("\\w\\+")
  local matches = {}
  for row = first, last do
    if #matches >= config.max_matches then
      break
    end
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    -- match_str has no start offset; advance by slicing the line.
    local offset = 0
    while true do
      local rest = line:sub(offset + 1)
      if #rest == 0 then
        break
      end
      local s, e = re:match_str(rest)
      if s == nil then
        break
      end
      local run_start = offset + s
      local run_end = offset + e
      offset = offset + (e > s and e or s + 1)
      for i = run_start, run_end - 1 do
        if #matches >= config.max_matches then
          break
        end
        if is_subword_start(line, i, run_start) then
          local before = row < cur.row or (row == cur.row and i < cur.col)
          local after = row > cur.row or (row == cur.row and i > cur.col)
          if (direction == "forward" and after) or (direction == "backward" and before) then
            matches[#matches + 1] = { row = row, col = i, before = before }
          end
        end
      end
    end
  end
  return matches
end

-- Word-level targets for s/S: the start of every run of keyword characters
-- or non-ASCII text. Punctuation is not a target: "foo.bar" gets labels on
-- foo and bar, not on the dot.
local function is_word_byte(b)
  return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95
end

local function collect_words(buf, cur, direction)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local first = math.max(0, vim.fn.line("w0") - 1)
  local last = math.min(vim.fn.line("w$") - 1, line_count - 1)
  local matches = {}
  for row = first, last do
    if #matches >= config.max_matches then
      break
    end
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    local prev_word = false
    for i = 0, #line - 1 do
      if #matches >= config.max_matches then
        break
      end
      local b = line:byte(i + 1)
      local is_word = b ~= 32 and b ~= 9 and (is_word_byte(b) or b >= 128)
      if is_word and not prev_word then
        local before = row < cur.row or (row == cur.row and i < cur.col)
        local after = row > cur.row or (row == cur.row and i > cur.col)
        if (direction == "forward" and after) or (direction == "backward" and before) then
          matches[#matches + 1] = { row = row, col = i, before = before }
        end
      end
      prev_word = is_word
    end
  end
  return matches
end

-- VSCodeVim sorts by distance to the cursor; at equal distance the match on
-- the left of the cursor wins. Ties keep document order (stable sort).
local function sort_by_proximity(matches, cursor_index)
  for i, m in ipairs(matches) do
    m.index = i
  end
  table.sort(matches, function(a, b)
    local da = math.abs(cursor_index - a.index)
    local db = math.abs(cursor_index - b.index)
    if a.index < cursor_index then
      da = da - 0.5
    end
    if b.index < cursor_index then
      db = db - 0.5
    end
    if da == db then
      return a.index < b.index
    end
    return da < db
  end)
end

-- VSCodeVim's MarkerGenerator, ported as-is: single-char labels come from
-- the front of the key list while there are enough keys; extra targets get
-- two-char labels whose first char comes from the end of the key list (the
-- last chars are reserved as prefixes so a typed char is never ambiguous).
local function make_labeler(count)
  local keys = vim.fn.split(config.keys, "\\zs")
  local k = #keys
  local steps = math.ceil(math.max(count - k, 0) / k)
  local prefixes = {}
  for i = 1, math.min(steps, k) do
    prefixes[i] = keys[k - i + 1]
  end
  return function(index) -- 0-based
    if index >= k - #prefixes then
      local remainder = index - (k - #prefixes)
      local step = math.floor(remainder / k) + 1
      if step > #prefixes then
        return nil
      end
      return prefixes[step] .. keys[(remainder % k) + 1]
    end
    return keys[index + 1]
  end
end

local function dim_visible_lines(buf)
  local top = vim.fn.line("w0") - 1
  local bottom = math.min(vim.fn.line("w$"), vim.api.nvim_buf_line_count(buf)) - 1
  for row = top, bottom do
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if line and #line > 0 then
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        end_row = row,
        end_col = #line,
        hl_group = hl.dim,
        priority = 1000,
      })
    end
  end
end

-- Draw the labels for the current typing depth: labels still matching the
-- typed keys show only their remaining characters, the rest are gone.
local function render(buf, markers, accumulated)
  clear_marks(buf)
  if #markers == 0 then
    return
  end
  if config.dim_background then
    dim_visible_lines(buf)
  end
  for _, marker in ipairs(markers) do
    if marker.name:sub(1, #accumulated) == accumulated then
      local keystroke = marker.name:sub(#accumulated + 1)
      local chunks
      if #keystroke > 1 then
        chunks = {
          { keystroke:sub(1, 1), hl.two_first },
          { keystroke:sub(2, 2), hl.two_second },
        }
      elseif #keystroke == 1 then
        chunks = { { keystroke, hl.one } }
      end
      if chunks then
        local line = vim.api.nvim_buf_get_lines(buf, marker.row, marker.row + 1, false)[1] or ""
        local end_col = math.min(marker.col + #keystroke, #line)
        if end_col <= marker.col then
          end_col = marker.col + 1
        end
        vim.api.nvim_buf_set_extmark(buf, ns, marker.row, marker.col, {
          end_row = marker.row,
          end_col = end_col,
          strict = false,
          virt_text = chunks,
          virt_text_pos = "overlay",
          priority = 200,
        })
      end
    end
  end
  vim.cmd("redraw")
end

local function restore_visual(started_in_visual)
  if started_in_visual then
    local keys = vim.api.nvim_replace_termcodes("<Esc>gv", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

-- Cancels a pending operator (e.g. after Esc during d<leader><leader>f).
local function cancel_operator()
  local keys = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end

-- In operator-pending mode, entering visual mode before moving the cursor
-- makes the pending operator apply to the jump (inclusive of the landing
-- character, like f/t in VSCodeVim's easymotion).
local function jump_to(buf, row, col, operator)
  clear_marks(buf)
  if operator then
    vim.cmd("normal! v")
  end
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

-- landing: "on" = land on the subword start (f/F), "before"/"after" = land
-- one character before/after it (t, T), like native t/T.
local function start(opts)
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur = { row = cursor[1] - 1, col = cursor[2] }
  local jumped = false

  local collect = opts.subword and collect_subwords or collect_words
  local matches = collect(buf, cur, opts.direction)
  if #matches == 0 then
    restore_visual(opts.visual)
    if opts.operator then
      cancel_operator()
    end
    return
  end

  local cursor_index = 0
  for _, m in ipairs(matches) do
    if m.before then
      cursor_index = cursor_index + 1
    end
  end
  sort_by_proximity(matches, cursor_index)

  local resolve
  if opts.landing == "before" then
    resolve = function(m)
      return { row = m.row, col = math.max(0, m.col - 1) }
    end
  elseif opts.landing == "after" then
    resolve = function(m)
      local line = vim.api.nvim_buf_get_lines(buf, m.row, m.row + 1, false)[1] or ""
      return { row = m.row, col = math.min(m.col + 1, #line) }
    end
  else
    resolve = function(m)
      return { row = m.row, col = m.col }
    end
  end

  local label = make_labeler(#matches)
  local markers = {}
  local seen = {}
  local index = 0
  for _, m in ipairs(matches) do
    local r = resolve(m)
    local key = r.row .. ":" .. r.col
    if not (r.row == cur.row and r.col == cur.col) and not seen[key] then
      seen[key] = true
      local name = label(index)
      index = index + 1
      if name then
        markers[#markers + 1] = { name = name, row = r.row, col = r.col }
      end
    end
  end
  if #markers == 0 then
    restore_visual(opts.visual)
    if opts.operator then
      cancel_operator()
    end
    return
  end

  -- Exactly one target: jump straight there, no labels (VSCodeVim behavior).
  if #matches == 1 then
    jumped = true
    jump_to(buf, markers[1].row, markers[1].col, opts.operator)
    restore_visual(opts.visual)
    return
  end

  local accumulated = ""
  render(buf, markers, accumulated)
  while true do
    local ok, key = pcall(vim.fn.getcharstr)
    -- Esc, Ctrl-C, or any multi-byte input cancels the jump.
    if not ok or type(key) ~= "string" or #key ~= 1 or key == "\27" or key == "\3" then
      break
    end
    local nail = accumulated .. key
    local hit, count = nil, 0
    for _, marker in ipairs(markers) do
      if marker.name:sub(1, #nail) == nail then
        hit, count = marker, count + 1
      end
    end
    if count == 1 then
      jumped = true
      jump_to(buf, hit.row, hit.col, opts.operator)
      break
    elseif count == 0 then
      break
    end
    accumulated = nail
    render(buf, markers, accumulated)
  end
  clear_marks(buf)
  restore_visual(opts.visual)
  if opts.operator and not jumped then
    cancel_operator()
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  define_highlights()
  local function bind(lhs, subword, direction, landing, desc)
    vim.keymap.set("n", lhs, function()
      start({ subword = subword, direction = direction, landing = landing, visual = false })
    end, { desc = desc })
    vim.keymap.set("x", lhs, function()
      start({ subword = subword, direction = direction, landing = landing, visual = true })
    end, { desc = desc })
    vim.keymap.set("o", lhs, function()
      start({ subword = subword, direction = direction, landing = landing, operator = true })
    end, { desc = desc })
  end
  bind("<leader><leader>w", false, "forward", "on", "Easy motion: jump to a word forwards")
  bind("<leader><leader>b", false, "backward", "on", "Easy motion: jump to a word backwards")
  bind("<leader><leader>f", true, "forward", "on", "Easy motion: jump to a subword forwards")
  bind("<leader><leader>t", true, "forward", "before", "Easy motion: jump before a subword forwards")
  bind("<leader><leader>F", true, "backward", "on", "Easy motion: jump to a subword backwards")
  bind("<leader><leader>T", true, "backward", "after", "Easy motion: jump after a subword backwards")
end

-- Test hooks.
M._test = {
  namespace = ns,
  collect = collect_subwords,
  collect_words = collect_words,
  labeler = make_labeler,
  render = render,
}

return M
