-- org-telescope – zentrale Konfiguration --------------------------------
local M = {}

M.defaults = {
  todo_states    = {
    { name = "TODO",     color = "#FF5555", highlight = "OrgTodoRed",  keymaps = { normal = "t", insert = "<C-t>" } },
    { name = "PROGRESS", color = "#FFAA00", highlight = "OrgProgress", keymaps = { normal = "p", insert = "<C-p>" } },
    { name = "DONE",     color = "#50FA7B", highlight = "OrgDone",     keymaps = { normal = "d", insert = "<C-d>" } },
    { name = "WAITING",  color = "#BD93F9", highlight = "OrgWaiting",  keymaps = { normal = "w", insert = "<C-w>" } },
  },

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
    filter_all          = { normal = "a", insert = "<C-a>" },
  },

  debug   = false,
}

function M.setup(user)
  _G.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user or {})
  if _G.config.org_folder then
    _G.config.org_folder = vim.fn.expand(_G.config.org_folder)
  end
  -- derive helper tables
  _G.config.todo_keywords   = {}
  _G.config.todo_highlights = {}
  _G.config.todo_keymaps    = {}
  for _, s in ipairs(_G.config.todo_states or {}) do
    table.insert(_G.config.todo_keywords, s.name)
    local hl = s.highlight or ("Org" .. s.name)
    _G.config.todo_highlights[s.name] = hl
    _G.config.todo_keymaps[s.name] = s.keymaps or {}
  end
  return _G.config
end

return M
