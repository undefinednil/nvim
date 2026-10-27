vim.lsp.config("*", {
  -- blink.cmp leaves out nvim's default capabilities (including semantic
  -- tokens) unless the second argument is true.
  capabilities = require("blink.cmp").get_lsp_capabilities({}, true),
})

vim.lsp.enable({ "gopls", "lua_ls", "phpactor", "ts_ls" })

local ok, local_cfg = pcall(dofile, vim.fn.stdpath("config") .. "/local.lua")
if ok and type(local_cfg) == "table" and type(local_cfg.lsp) == "table" then
  for name, cfg in pairs(local_cfg.lsp) do
    vim.lsp.config(name, cfg)
  end
end

-- The first file argument can be loaded before init.lua runs, so its FileType
-- event fires before vim.lsp.enable() registers its listener. Replay the
-- enable callback once startup is done (same mechanism vim.lsp.enable() uses
-- when called after startup).
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd.doautoall("nvim.lsp.enable FileType")
  end,
})

-- Hover popup (K) with padding around the content.
vim.lsp.handlers["textDocument/hover"] = function(_, result, ctx, config)
  if not (result and result.contents) then
    return
  end
  local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
  while #lines > 0 and (lines[1] == "" or lines[1] == vim.NIL) do
    table.remove(lines, 1)
  end
  while #lines > 0 and (lines[#lines] == "" or lines[#lines] == vim.NIL) do
    table.remove(lines)
  end
  if vim.tbl_isempty(lines) then
    return
  end
  for i, line in ipairs(lines) do
    lines[i] = "  " .. line
  end
  table.insert(lines, 1, " ")
  lines[#lines + 1] = " "
  return vim.lsp.util.open_floating_preview(lines, "markdown", config)
end
