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

-- Hover popup (K) with padding around the content. `vim.lsp.buf.hover()` no
-- longer goes through `vim.lsp.handlers`; it opens the float itself with
-- `open_floating_preview` and tags the config with focus_id, so pad there.
local open_floating_preview = vim.lsp.util.open_floating_preview
vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
  if opts and opts.focus_id == "textDocument/hover" and type(contents) == "table" then
    local padded = { " " }
    for _, line in ipairs(contents) do
      padded[#padded + 1] = "  " .. line .. "  "
    end
    padded[#padded + 1] = " "
    contents = padded
  end
  return open_floating_preview(contents, syntax, opts, ...)
end
