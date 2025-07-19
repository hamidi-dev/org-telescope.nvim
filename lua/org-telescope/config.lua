-- org-telescope – zentrale Konfiguration --------------------------------
local M = {}

M.defaults = {
  max_headline_level = 2,
  history_file       = vim.fn.stdpath("state") .. "/org-telescope/history.json",
  auto_prune         = false,
  todo_keywords      = { "TODO", "PROGRESS", "DONE", "WAITING" },

  picker             = {
    initial_mode = "insert",
    reverse_sort = true,
  },

  -- File-Scope ---------------------------------------------------------
  patterns           = { "*.org" },
  org_folder         = nil,
  exclude_files      = {},

  smart_tracking     = {
    enabled          = true,
    auto_update      = true,
    search_all_files = true,
  },

  refile             = {
    default_mode = "file",    -- or "heading"
  },

  browse            = {
    preview = false,        -- start headline browser without preview
  },

  -- Keymaps (original Layout) -----------------------------------------
  keymaps            = {
    open_history        = "<localleader>oh",
    browse_all          = "<localleader>ob",
    clear_history       = "<localleader>ohc",

    refile_heading      = "<localleader>or",

    toggle_sort         = "<C-r>",
    toggle_level_filter = "<C-l>",
    toggle_preview      = "<C-x>",

    delete_entry        = { normal = "D", insert = "<C-d>" },

    todo_filters        = {
      normal = { todo = "t", progress = "p", done = "d", waiting = "w", all = "a" },
      insert = { todo = "<C-t>", progress = "<C-p>", done = "<C-d>", waiting = "<C-w>", all = "<C-a>" },
    },
  },

  debug              = false,
}

function M.setup(user)
  _G.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user or {})
  return _G.config
end

return M
