local undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir, "p")
vim.o.undodir = undo_dir

vim.o.completeopt = "menuone,noselect,popup"
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.fileencodings = "ucs-bom,utf-8,gb18030,gbk,big5,latin1"

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = true,
})

vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
      vim.cmd("silent! update")
    end
  end,
})

vim.api.nvim_set_hl(0, "YankFlash", { bg = "#627384" })
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ higroup = "YankFlash", timeout = 300 })
  end,
})
