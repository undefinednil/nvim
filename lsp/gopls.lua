return {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.work", "go.mod", ".git" },
  init_options = {
    -- gopls advertises the semantic tokens provider only when this arrives
    -- in initializationOptions, not via workspace/configuration.
    semanticTokens = true,
  },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
    },
  },
}
