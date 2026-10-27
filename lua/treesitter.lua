local M = {}

M.langs = {
  "bash",
  "css",
  "dockerfile",
  "go",
  "gomod",
  "gosum",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "php",
  "query",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

function M.setup()
  require("nvim-treesitter").install(M.langs)

  vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
      pcall(vim.treesitter.start, args.buf)
    end,
  })
end

return M
