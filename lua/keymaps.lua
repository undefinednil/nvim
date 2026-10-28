require("easymotion").setup()
require("sidebar").setup()
require("mru").setup()
require("refs").setup()
require("lazygit").setup()

vim.keymap.set("n", "<C-e>", function() require("fzf-lua").files() end, { desc = "Find files" })
vim.keymap.set("n", "<C-S-f>", function() require("fzf-lua").live_grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>ff", function() require("fzf-lua").files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function() require("fzf-lua").live_grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function() require("fzf-lua").buffers() end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", function() require("fzf-lua").help_tags() end, { desc = "Find help" })
vim.keymap.set("n", "<leader>fo", function() require("fzf-lua").oldfiles() end, { desc = "Recent files" })

vim.keymap.set({ "n", "v" }, "<leader>c", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format" })

vim.keymap.set("n", "-", function() require("oil").open() end, { desc = "Open parent directory" })
vim.keymap.set("n", "<C-b>", function() require("sidebar").toggle() end, { desc = "Toggle file tree sidebar" })
-- Window switching on <C-h>/<C-l>. Falls back to the sidebar shortcuts when
-- there is no window in that direction: <C-h> opens/focuses the sidebar,
-- <C-l> returns to the main window. For stacked windows use the builtin
-- <C-w>j / <C-w>k.
local function win_switch(dir)
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. dir)
  if vim.api.nvim_get_current_win() ~= cur then
    return
  end
  if dir == "h" then
    require("sidebar").focus()
  elseif dir == "l" then
    require("sidebar").focus_main()
  end
end
for _, dir in ipairs({ "h", "l" }) do
  vim.keymap.set("n", "<C-" .. dir .. ">", function()
    win_switch(dir)
  end, { desc = dir == "h" and "Focus left window or sidebar" or "Focus right window or main" })
end

vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
vim.keymap.set("n", "<leader>oi", function()
  vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" }, diagnostics = {} }, apply = true })
end, { desc = "Organize imports" })
vim.keymap.set("n", "<leader>gc", vim.lsp.buf.incoming_calls, { desc = "Incoming calls" })

vim.keymap.set({ "n", "o", "x" }, "<leader>w", "<cmd>lua require('spider').motion('w')<CR>", { desc = "Subword forward" })
vim.keymap.set({ "n", "o", "x" }, "<leader>b", "<cmd>lua require('spider').motion('b')<CR>", { desc = "Subword backward" })
vim.keymap.set({ "n", "o", "x" }, "<leader>e", "<cmd>lua require('spider').motion('e')<CR>", { desc = "Subword end" })

vim.keymap.set("n", "]c", function() require("gitsigns").nav_hunk("next") end, { desc = "Next git hunk" })
vim.keymap.set("n", "[c", function() require("gitsigns").nav_hunk("prev") end, { desc = "Previous git hunk" })
vim.keymap.set("n", "<leader>hs", function() require("gitsigns").stage_hunk() end, { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>hr", function() require("gitsigns").reset_hunk() end, { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>hp", function() require("gitsigns").preview_hunk() end, { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>hb", function() require("gitsigns").blame_line({ full = true }) end, { desc = "Blame line" })

vim.keymap.set("n", "<leader>hc", function()
  local refs = vim.fn.systemlist({
    "git", "for-each-ref", "--sort=-committerdate", "--format=%(refname:short)",
    "refs/heads", "refs/remotes",
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("Not a git repository", vim.log.levels.WARN)
    return
  end
  local branches = vim.tbl_filter(function(ref)
    return not vim.endswith(ref, "/HEAD")
  end, refs)
  if #branches == 0 then
    vim.notify("No branches to compare against", vim.log.levels.WARN)
    return
  end
  require("fzf-lua").fzf_exec(branches, {
    prompt = "Compare with branch> ",
    actions = {
      ["default"] = function(selected)
        if selected[1] and selected[1] ~= "" then
          vim.cmd("CodeDiff " .. vim.fn.fnameescape(selected[1]))
        end
      end,
    },
  })
end, { desc = "Compare with branch" })
