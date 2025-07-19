-- org-telescope – zentrale Konfiguration --------------------------------
local M = {}

M.defaults = {
  todo_keywords  = { "TODO", "PROGRESS", "DONE", "WAITING" },

  picker         = {
    initial_mode = "insert",
    reverse_sort = true,
  },

  pickers        = {
    browse_headlines = { initial_mode = "insert", preview = false },
    browse_history   = { initial_mode = "normal", preview = true },
    refile           = { initial_mode = "insert", preview = true },
  },

  -- File-Scope ---------------------------------------------------------
  patterns       = { "*.org" },
  org_folder     = nil,
  exclude_files  = {},

  smart_tracking = {
    enabled          = true,
    auto_update      = true,
    search_all_files = true,
  },

  refile         = {
    default_mode = "file", -- or "heading"
  },

  history        = {
    history_file       = vim.fn.stdpath("state") .. "/org-telescope/history.json", -- file to store history
    auto_prune         = false,                                                    -- automatically prune history on startup
    max_headline_level = 2,                                                        -- max level to track in history
    org_folder_only    = false,
  },


  -- Keymaps (original Layout) -----------------------------------------
  keymaps = {
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

  debug   = false,
}

function M.setup(user)
  _G.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user or {})
  if _G.config.org_folder then
    _G.config.org_folder = vim.fn.expand(_G.config.org_folder)
  end
  return _G.config
end

return M
