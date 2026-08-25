---@meta gnupg
---@class                    GnuPG.Recipients
---@field valid                                            string
---@field unknown                                          string[]
---@class GnuPG.SystemCmd
---@field level                                            integer Debug level for logging
---@field args                                             string GPG command arguments
---@class GnuPG.ExecuteCmd
---@field level                                            integer Debug level for logging
---@field args                                             string GPG command arguments
---@field ex                                               string Ex command prefix (e.g., 'write !', 'read !')
---@field redirect?                                        string Shell redirect string
---@class GnuPG.ShellescapeOpts
---@field special?                                         boolean Pass through as special argument for shellescape
---@field cygpath?                                         boolean When true and using Cygwin, adjust path for Gpg4win
---@class GnuPG.Config
---@field GPGExecutable?                                   string Path to GPG executable (default: 'gpg --trust-model always')
---@field GPGUseAgent?                                     0|1 Enable gpg-agent (default: 1)
---@field GPGPreferSymmetric?                              0|1 Prefer symmetric encryption (default: 0)
---@field GPGPreferSign?                                   0|1 Prefer signing files (default: 0)
---@field GPGPreferArmor?                                  -1|0|1 Prefer ASCII-armored output (default: -1)
---@field GPGDefaultRecipients?                            string[] Default recipient list
---@field GPGPossibleRecipients?                           string[] List of possible recipients for UI
---@field GPGUsePipes?                                     0|1 Use pipes instead of temp files (default: 0)
---@field GPGHomedir?                                      string Alternate GnuPG home directory
---@field GPGDebugLevel?                                   integer
---@field GPGDebugLog?                                     string
---@class                    GnuPG.BufferState
---@field GPGEncrypted?                                    0|1|integer
---@field GPGRecipients?                                   string[]
---@field GPGOptions?                                      string[]

---@class                    gnupg
local M = {}
---@param bufread                                          boolean True if called from BufReadCmd, false from FileReadCmd
---@return nil
function M.init(bufread) end

---@param bufread                                          boolean True if called from BufReadCmd, false from FileReadCmd
---@return nil
function M.decrypt(bufread) end

---@return nil
function M.encrypt() end

---@return nil
function M.view_recipients() end

---@return nil
function M.edit_recipients() end

---@return nil
function M.view_options() end

---Opens an interface to modify GPG options for the current buffer.
---Full implementation would create an editable scratch buffer.
---
---@return nil
function M.edit_options() end

return M