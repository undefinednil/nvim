local M = {}

local js = {
  print = "console.log(${1});",
  log = "console.log(`========== ${1} ==========`);",
  error = "try {\n  ${1}\n} catch (e) {\n  console.log(e);\n}",
}

local snippets = {
  javascript = js,
  javascriptreact = js,
  typescript = js,
  typescriptreact = js,
  vue = js,
  go = {
    print = "fmt.Println(${1})",
    log = 'fmt.Println("========== ${1} ==========")',
    error = "if err != nil {\n    return nil, err\n}",
  },
  python = {
    print = "print(${1})",
    log = 'print("========== ${1} ==========")',
  },
  php = {
    print = "info(json_encode(\\$${1}, JSON_PRETTY_PRINT));",
    log = "info('========== ${1} ==========');",
  },
}

local function indent_continuation_lines(text)
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local indent = line:sub(1, col):match("^%s*") or ""
  local lines = vim.split(text, "\n", { plain = true })
  for i = 2, #lines do
    if lines[i] ~= "" then
      lines[i] = indent .. lines[i]
    end
  end
  return table.concat(lines, "\n")
end

function M.insert(kind)
  local ft = vim.bo.filetype
  local group = snippets[ft]
  if not group or not group[kind] then
    return
  end
  vim.snippet.expand(indent_continuation_lines(group[kind]))
  vim.cmd.startinsert()
end

vim.keymap.set("n", "<leader>gp", function() M.insert("print") end, { desc = "Insert print" })
vim.keymap.set("n", "<leader>gl", function() M.insert("log") end, { desc = "Insert log" })
vim.keymap.set("n", "<leader>ge", function() M.insert("error") end, { desc = "Insert error" })

return M
