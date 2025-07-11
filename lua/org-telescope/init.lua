-- Org-telescope – Entry-Point  ------------------------------------------
local cfg      = require("org-telescope.config")
local util     = require("org-telescope.util")
local headline = require("org-telescope.headline")
local refile   = require("org-telescope.refile")

local M        = {}

local teles
local history

local function track()
  local file = vim.api.nvim_buf_get_name(0)
  if not file:match("%.org$") then return end
  for _, ex in ipairs(config.exclude_files) do
    if file == ex or vim.fn.fnamemodify(file, ":t") == ex then return end
  end
  local hl = headline.current(); if not hl then return end
  history.add(file, vim.api.nvim_win_get_cursor(0)[1], hl)
end

function M.setup(user)                     -- Public
  cfg.setup(user)
  teles   = require("org-telescope.telescope")
  history = require("org-telescope.history")

  vim.cmd([[highlight link OrgTodo Todo]])
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = config.patterns,
    callback = function(a)
      vim.api.nvim_create_autocmd("CursorMoved", { buffer = a.buf, callback = track })
    end
  })
  local km = config.keymaps
  vim.keymap.set("n", km.open_history, teles.open_history, { desc = "Org-History" })
  vim.keymap.set("n", km.browse_all, teles.open_all_headlines, { desc = "Org-Headlines" })
  vim.keymap.set("n", km.clear_history, history.clear, { desc = "Org-History clear" })
  if km.refile_heading then
    vim.keymap.set("n", km.refile_heading, refile.refile_current_heading, { desc = "Org-Refile" })
  end
  util.log("Org-telescope ready 🎉")
end

return M
