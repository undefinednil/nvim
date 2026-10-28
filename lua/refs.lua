local M = {}

-- Position of the reference under the request position within the result
-- list, so the picker can start its cursor on the current reference.
-- Both the cursor position (ctx.params) and the ranges are in the client's
-- offset encoding, so no conversion is needed.
local function locate_from_results(result, ctx)
  local pos = ctx.params and ctx.params.position
  if not pos then
    return nil
  end
  local cur_uri = vim.uri_from_bufnr(ctx.bufnr)
  local idx = 0
  for _, loc in ipairs(result or {}) do
    idx = idx + 1
    if loc.uri == cur_uri and loc.range.start.line == pos.line then
      if pos.character >= loc.range.start.character and pos.character <= loc.range["end"].character then
        return idx
      end
    end
  end
  return nil
end

function M.setup()
  -- Nvim's default `grr` lands references in a quickfix list. Route
  -- textDocument/references to the fzf-lua picker instead, with the cursor
  -- on the current reference. Other gr* defaults are untouched.
  vim.lsp.handlers["textDocument/references"] = function(_, result, ctx, _)
    require("fzf-lua").lsp_references({
      includeDeclaration = true,
      locate = true,
      __locate_pos = locate_from_results(result, ctx),
    })
  end
end

M._locate_from_results = locate_from_results

return M
