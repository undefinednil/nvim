-- Best-effort highlighting for files Neovim does not recognize.
-- When a buffer has no filetype (or only the generic "text"), look at the
-- content instead: JSON, TOML, HTML or YAML-looking text gets that filetype
-- so treesitter can color it (e.g. a .enc file that holds JSON).

local MAX_LINES = 5000
local MAX_BYTES = 256 * 1024

local function sample(buf)
  local count = vim.api.nvim_buf_line_count(buf)
  local last = math.min(count, MAX_LINES)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, last, false)
  return table.concat(lines, "\n"), last < count
end

local function looks_like_json(text, truncated)
  local head = vim.trim(text)
  if head == "" or (head:sub(1, 1) ~= "{" and head:sub(1, 1) ~= "[") then
    return false
  end
  -- A partial sample cannot decode; leave big files alone.
  if truncated then
    return false
  end
  return (pcall(vim.json.decode, text))
end

local function looks_like_html(text)
  for line in vim.gsplit(text, "\n", { plain = true }) do
    local head = vim.trim(line):lower()
    if head ~= "" then
      return head:match("^<!doctype%s+html") ~= nil or head:match("^<html[%s>]") ~= nil
    end
  end
  return false
end

local function looks_like_toml(text)
  local section, assignment = false, false
  for line in vim.gsplit(text, "\n", { plain = true }) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^#") then
      if trimmed:match("^%[[%w%._%-]+%]%s*$") then
        section = true
      elseif trimmed:match("^[%w%._%-]+%s*=") then
        assignment = true
      end
    end
  end
  return section and assignment
end

local function looks_like_yaml(text)
  local key_lines, list_lines = 0, 0
  for line in vim.gsplit(text, "\n", { plain = true }) do
    if line:match("^%s*[%w%._%-]+%s*:") then
      key_lines = key_lines + 1
    elseif line:match("^%s*%-%s") then
      list_lines = list_lines + 1
    end
  end
  return key_lines >= 2 or (key_lines >= 1 and list_lines >= 1)
end

local detectors = {
  { "json", looks_like_json },
  { "html", looks_like_html },
  { "toml", looks_like_toml },
  { "yaml", looks_like_yaml },
}

local function sniff(buf)
  local ft = vim.bo[buf].filetype
  if ft ~= "" and ft ~= "text" then
    return
  end
  if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
    return
  end
  local text, truncated = sample(buf)
  if text == "" or text:find("\0", 1, true) then
    return
  end
  -- A UTF-8 BOM would hide the first character from the detectors.
  text = (text:gsub("^\239\187\191", ""))
  for _, detector in ipairs(detectors) do
    if detector[2](text, truncated) then
      vim.bo[buf].filetype = detector[1]
      return
    end
  end
end

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(args)
    sniff(args.buf)
  end,
})
