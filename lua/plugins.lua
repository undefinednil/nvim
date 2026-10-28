vim.pack.add({
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/esmuellert/codediff.nvim",
  -- File icons (Material Design glyphs) for codediff, the oil sidebar, and
  -- fzf-lua pickers.
  "https://github.com/nvim-mini/mini.icons",
  "https://github.com/stevearc/oil.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/folke/which-key.nvim",
  -- Pinned to v1 tags: blink v2 is pre-release, and blink only downloads its
  -- fuzzy binary from an exact git tag (a branch checkout makes it error).
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("^1.10") },
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/chrisgrieser/nvim-spider",
})

vim.cmd.colorscheme("jetmind")

-- mini.icons is the icon source everywhere: oil and fzf-lua use it directly,
-- and codediff asks for nvim-web-devicons by name, which the mock provides.
require("mini.icons").setup({})
MiniIcons.mock_nvim_web_devicons()

require("fzf-lua").setup({
  defaults = { file_icons = "mini" },
  grep = {
    -- fzf-lua runs ripgrep with --color=always, so the result list shows
    -- ripgrep's own colors (magenta paths, bold red matches). Override them
    -- with JetMind colors: soft white paths, gray line numbers, themed blue
    -- matches.
    rg_opts = "--column --line-number --no-heading --color=always --smart-case "
      .. "--colors=path:fg:252 "
      .. "--colors=line:fg:245 "
      .. "--colors=column:fg:245 "
      .. "--colors=match:fg:39 "
      .. "--colors=match:style:nobold",
  },
})
require("gitsigns").setup({})
require("codediff").setup({
  explorer = { view_mode = "tree" },
})
require("oil").setup({
  delete_to_trash = true,
  -- Keep the global signcolumn as left padding (oil turns it off by default).
  win_options = { signcolumn = "yes" },
  view_options = { show_hidden = true },
  keymaps = {
    -- Oil sets buffer-local keymaps, which would shadow these global ones.
    ["<CR>"] = {
      desc = "Open file in the main window",
      callback = function()
        if require("sidebar").select_in_main_win() then
          return
        end
        require("oil.actions").select.callback()
      end,
    },
    ["<C-h>"] = {
      desc = "Focus file tree sidebar",
      callback = function()
        require("sidebar").focus()
      end,
    },
    ["<C-l>"] = {
      desc = "Focus main window",
      callback = function()
        require("sidebar").focus_main()
      end,
    },
  },
})
require("which-key").setup({})
require("which-key").add({
  { "<leader>f", group = "find" },
  { "<leader>g", group = "generate" },
  { "<leader>h", group = "git hunks" },
  { "<leader>l", group = "launch" },
  { "<leader>s", group = "search" },
})

require("treesitter").setup()

require("blink.cmp").setup({
  keymap = {
    preset = "none",
    ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
    ["<C-p>"] = { "select_prev", "fallback" },
    ["<C-n>"] = { "select_next", "fallback" },
    ["<C-y>"] = { "accept", "fallback" },
    ["<C-e>"] = { "cancel", "fallback" },
    ["<C-space>"] = { "show", "fallback" },
  },
  completion = {
    documentation = { auto_show = true },
  },
})

require("conform").setup({
  formatters = {
    prettier = {
      -- This machine has bun instead of node, and the prettier bin has a
      -- `#!/usr/bin/env node` shebang, so run it through bun.
      command = "bun",
      args = { "x", "prettier", "--stdin-filepath", "$FILENAME" },
      range_args = { "x", "prettier", "--stdin-filepath", "$FILENAME" },
    },
  },
  formatters_by_ft = {
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    vue = { "prettier" },
    json = { "prettier" },
    jsonc = { "prettier" },
    yaml = { "prettier" },
    css = { "prettier" },
    scss = { "prettier" },
    html = { "prettier" },
  },
})

require("spider").setup({})
