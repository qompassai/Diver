local M = {}

M.commentstring = '; %s'
vim.bo.commentstring = M.commentstring

return M
