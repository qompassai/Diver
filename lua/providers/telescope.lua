local T = require("trouble.sources.telescope")

return {
  open = function(prompt_bufnr, opts)
    T.open(prompt_bufnr, opts)
  end,
  add = function(prompt_bufnr, opts)
    T.add(prompt_bufnr, opts)
  end
}

