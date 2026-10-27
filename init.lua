vim.loader.enable()

vim.g.mapleader = " "

local vimrc = vim.fn.stdpath("config") .. "/.vimrc"
if vim.fn.filereadable(vimrc) == 1 then
  vim.cmd.source(vimrc)
end

require("options")
require("sniff_filetype")
require("plugins")
require("lsp")
require("keymaps")
require("generate")
