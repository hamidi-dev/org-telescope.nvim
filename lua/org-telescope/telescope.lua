-- Org-telescope – Telescope-Picker (komplett) ----------------------------
local util          = require("org-telescope.util")
local history       = require("org-telescope.history")
local scanner       = require("org-telescope.scanner")
local customPickers = require("org-telescope.pickers")

local T             = {}

-- Local Picker-State (Filter & Sort)
local state         = {
  active_level_filter = nil,
  active_todo_filter  = nil,
  reverse_sort        = config.picker.reverse_sort,
  show_preview        = true,
}

-- ---------------------------------------------------------------------
local function telescope_ok()
  local ok = pcall(require, "telescope")
  if not ok then util.log("Telescope not installiert!", vim.log.levels.ERROR) end
  return ok
end

-- Finder / Previewer helpers ------------------------------------------

local function entry_maker(show_time)
  local entry_display = require("telescope.pickers.entry_display")
  local displayer
  if show_time then
    displayer = entry_display.create {
      separator = " ",
      items = { { width = 8 }, { width = 1 }, { width = 50 }, { width = 1 }, { width = 16 }, { width = 20 } },
    }
  else
    displayer = entry_display.create {
      separator = " ",
      items = { { width = 8 }, { width = 1 }, { width = 70 }, { width = 1 }, { width = 20 } },
    }
  end
  return function(entry, idx)
    local indent = string.rep("  ", entry.level - 1)
    local todo   = entry.todo_state or ""
    local file_i = "(" .. vim.fn.fnamemodify(entry.file, ":t") .. ":" .. entry.line .. ")"

    local function disp()
      local sep  = { "│", "Comment" }
      local fp   = { file_i, "Comment" }
      local time = show_time and { entry.time and entry.time:sub(1, 16) or "---", "Comment" } or nil
      local td_hl
      if todo == "TODO" then
        td_hl = "OrgTodoRed"
      elseif todo == "PROGRESS" then
        td_hl = "OrgProgress"
      elseif todo == "DONE" then
        td_hl = "OrgDone"
      elseif todo == "WAITING" then
        td_hl = "OrgWaiting"
      end
      if todo ~= "" then
        if show_time then
          return displayer { { todo, td_hl }, sep, { indent .. (entry.headline_text or entry.text), "Normal" }, sep, time, fp }
        else
          return displayer { { todo, td_hl }, sep, { indent .. (entry.headline_text or entry.text), "Normal" }, sep, fp }
        end
      else
        if show_time then
          return displayer { { "---", "Comment" }, sep, { indent .. entry.headline_text, "Normal" }, sep, time, fp }
        else
          return displayer { { "---", "Comment" }, sep, { indent .. entry.headline_text, "Normal" }, sep, fp }
        end
      end
    end

    return {
      value   = entry,
      ordinal = show_time and (entry.text .. " " .. (entry.time or "") .. " " .. file_i)
          or (entry.text .. " " .. file_i),
      index   = idx,
      display = disp,
      path    = entry.file, -- 👈 wichtig!
      lnum    = entry.line, -- optional
    }
  end
end

-- ---------------------------------------------------------------------
local function filter_entries(entries)
  local res = vim.tbl_filter(function(e)
    if state.active_level_filter and e.level ~= state.active_level_filter then return false end
    if state.active_todo_filter and e.todo_state ~= state.active_todo_filter then return false end
    return true
  end, entries)
  if state.reverse_sort then res = vim.fn.reverse(res) end
  return res
end

-- ---------------------------------------------------------------------
function T.open_telescope_picker(opts)
  if not telescope_ok() then return end
  customPickers.highlight_groups()

  local pickers, finders, conf, actions, action_state =
      require("telescope.pickers"), require("telescope.finders"),
      require("telescope.config").values, require("telescope.actions"),
      require("telescope.actions.state")

  local filtered                                      = filter_entries(opts.entries)

  local show_time                                     = opts.show_time ~= false

  local picker                                        = pickers.new({
    initial_mode = opts.initial_mode or config.picker.initial_mode,
    results_title = opts.results_title,
    layout_config = { width = 0.9, height = 0.8, preview_width = 0.65 },
  }, {
    prompt_title    = opts.prompt_title,
    finder          = finders.new_table { results = filtered, entry_maker = entry_maker(show_time) },
    sorter          = conf.generic_sorter({}),
    previewer       = customPickers.custom_previewer(),
    attach_mappings = function(bufnr, map)
      local function refresh() action_state.get_current_picker(bufnr):refresh_previewer() end
      map("n", "j", function()
        actions.move_selection_next(bufnr); refresh()
      end)
      map("n", "k", function()
        actions.move_selection_previous(bufnr); refresh()
      end)

      -- Jump-to-Entry --------------------------------------------------
      local function jump()
        local sel = action_state.get_selected_entry()
        actions.close(bufnr); history.jump(sel.value)
      end
      map("i", "<CR>", jump); map("n", "<CR>", jump)

      -- Toggle Sort / Level-Filter ------------------------------------
      local function re_open()
        local mode = (vim.api.nvim_get_mode().mode == 'i') and 'insert' or 'normal'
        actions.close(bufnr); opts.open_picker { initial_mode = mode, reset_filters = false }
      end
      map("n", config.keymaps.toggle_sort, function()
        state.reverse_sort = not state.reverse_sort; re_open()
      end)
      map("i", config.keymaps.toggle_sort, function()
        state.reverse_sort = not state.reverse_sort; re_open()
      end)

      map("n", config.keymaps.toggle_level_filter, function()
        state.active_level_filter = state.active_level_filter and nil or 1; re_open()
      end)
      map("i", config.keymaps.toggle_level_filter, function()
        state.active_level_filter = state.active_level_filter and nil or 1; re_open()
      end)

      -- Preview Toggle -------------------------------------------------
      if opts.allow_preview_toggle and config.keymaps.toggle_preview then
        local layout_actions = require("telescope.actions.layout")
        if not state.show_preview then
          vim.schedule(function() layout_actions.toggle_preview(bufnr) end)
        end
        map("n", config.keymaps.toggle_preview, function()
          state.show_preview = not state.show_preview
          layout_actions.toggle_preview(bufnr)
        end)
        map("i", config.keymaps.toggle_preview, function()
          state.show_preview = not state.show_preview
          layout_actions.toggle_preview(bufnr)
        end)
      end

      -- TODO-Filter ----------------------------------------------------
      local function todo_filter(val)
        return function()
          state.active_todo_filter = val; re_open()
        end
      end
      local nf, if_ = config.keymaps.todo_filters.normal, config.keymaps.todo_filters.insert
      map("n", nf.todo, todo_filter("TODO"))
      map("n", nf.progress, todo_filter("PROGRESS"))
      map("n", nf.done, todo_filter("DONE"))
      map("n", nf.waiting, todo_filter("WAITING"))
      map("n", nf.all, todo_filter(nil))
      map("i", if_.todo, todo_filter("TODO"))
      map("i", if_.progress, todo_filter("PROGRESS"))
      map("i", if_.done, todo_filter("DONE"))
      map("i", if_.waiting, todo_filter("WAITING"))
      map("i", if_.all, todo_filter(nil))

      -- Delete-Entry(s) (nur History-Picker) --------------------------
      if opts.allow_deletion then
        local function delete_sel()
          local pk = action_state.get_current_picker(bufnr)
          local multi = pk:get_multi_selection()
          if #multi == 0 then multi = { action_state.get_selected_entry() } end
          local idxs = {}
          for _, s in ipairs(multi) do
            local hist_idx = state.reverse_sort and (#filtered - s.index + 1) or s.index
            table.insert(idxs, hist_idx)
          end
          if #idxs > 0 then history.delete_multiple(idxs) end
          re_open()
        end
        local km = config.keymaps.delete_entry
        if km.normal then map("n", km.normal, delete_sel) end
        if km.insert then map("i", km.insert, delete_sel) end
      end

      -- Multi-Select with <Tab>
      map("n", "<Tab>", function()
        actions.toggle_selection(bufnr); actions.move_selection_previous(bufnr); refresh()
      end)
      map("i", "<Tab>", function()
        actions.toggle_selection(bufnr); actions.move_selection_previous(bufnr); refresh()
      end)

      ----------------------------------------------------------------------
      -- 1) nächster TODO-State
      local function next_state(cur)
        local L = config.todo_keywords
        if not cur then return L[1] end
        for i, k in ipairs(L) do
          if k == cur then return L[i % #L + 1] end
        end
        return L[1]
      end

      ----------------------------------------------------------------------
      -- 2) Headline umschalten
      local function toggle_headline(e)
        local path, ln = e.file, e.line -- ln ist 1-basiert
        if vim.fn.filereadable(path) ~= 1 then return end

        local lines          = vim.fn.readfile(path)
        local old            = lines[ln] or ""
        local stars, kw, txt = old:match("^(%*+)%s+(%u+)%s+(.*)")
        if not stars then stars, txt = old:match("^(%*+)%s+(.*)") end
        if not stars then return end

        local new_kw = next_state(kw)
        lines[ln]    = ("%s %s %s"):format(stars, new_kw, txt)
        vim.fn.writefile(lines, path)

        -- Eintrag anpassen & Anzeige erneuern
        e.todo_state = new_kw
        e.text       = new_kw .. " " .. (e.headline_text or txt)
        e.display    = nil -- wichtig!
      end

      ----------------------------------------------------------------------
      -- 3) Picker neu zeichnen & wieder auswählen
      local function refresh_and_reselect(pk, key)
        -- Aktualisiere die Einträge in opts.entries mit dem neuen TODO-Status
        for _, entry in ipairs(opts.entries) do
          if entry.file == key.file and entry.line == key.line then
            entry.todo_state = key.todo_state
            entry.text = key.text
            entry.headline_text = key.headline_text
            break
          end
        end

        pk:refresh( -- komplett neuer Finder
          require("telescope.finders").new_table {
            results     = filter_entries(opts.entries),
            entry_maker = entry_maker(show_time),
          },
          { reset_prompt = false } -- Cursor/Prompt behalten
        )

        -- Ergebnisliste hängt jetzt in pk.finder.results
        for idx, item in ipairs(pk.finder.results) do
          local v = item.value
          if v and v.file == key.file and v.line == key.line then
            pk:set_selection(idx)
            break
          end
        end
        pk:refresh_previewer()
      end

      ----------------------------------------------------------------------
      -- 4) Keymaps
      map("n", "c", function()
        local pk   = action_state.get_current_picker(bufnr)
        local sels = pk:get_multi_selection()
        if #sels == 0 then sels = { action_state.get_selected_entry() } end

        for _, s in ipairs(sels) do toggle_headline(s.value) end
        refresh_and_reselect(pk, sels[1].value)
      end)

      map("i", "<C-c>", function()
        local pk  = action_state.get_current_picker(bufnr)
        local sel = action_state.get_selected_entry(); if not sel then return end
        toggle_headline(sel.value)
        refresh_and_reselect(pk, sel.value)
      end)


      return true
    end,
  })
  picker:find()
end

local did_auto_prune = false
-- ---------------------------------------------------------------------
function T.open_history(opts)
  opts = opts or {}; if opts.reset_filters ~= false then
    state.active_level_filter = nil; state.active_todo_filter = nil
  end
  opts.entries              = history.all()
  opts.prompt_title         = "Org Headline History" ..
      (state.active_todo_filter and (" - " .. state.active_todo_filter) or "")
      .. (state.active_level_filter and (" - Level " .. state.active_level_filter) or "")
  local k                   = config.keymaps
  opts.results_title        = string.format(
    "Filter: [%s]todo [%s]rogress [%s]one [%s]aiting [%s]ll | [%s] Level | [%s] Sort",
    k.todo_filters.normal.todo, k.todo_filters.normal.progress, k.todo_filters.normal.done,
    k.todo_filters.normal.waiting, k.todo_filters.normal.all,
    k.toggle_level_filter:gsub("[<>]", ""), k.toggle_sort:gsub("[<>]", ""))
  opts.open_picker          = T.open_history
  opts.allow_deletion       = true
  state.show_preview        = config.pickers.browse_history.preview
  opts.initial_mode         = config.pickers.browse_history.initial_mode
  opts.show_time            = true
  opts.allow_preview_toggle = true

  if config.auto_prune and not did_auto_prune then
    did_auto_prune = true
    history.prune()
  end
  T.open_telescope_picker(opts)
end

function T.open_all_headlines(opts)
  opts = opts or {}; if opts.reset_filters ~= false then
    state.active_level_filter = nil; state.active_todo_filter = nil
  end
  opts.entries              = scanner.scan()
  opts.prompt_title         = "All Org Headlines" ..
      (state.active_todo_filter and (" - " .. state.active_todo_filter) or "")
      .. (state.active_level_filter and (" - Level " .. state.active_level_filter) or "")
  local k                   = config.keymaps
  opts.results_title        = string.format(
    "Filter: [%s]todo [%s]rogress [%s]one [%s]aiting [%s]ll | [%s] Level | [%s] Sort",
    k.todo_filters.normal.todo, k.todo_filters.normal.progress, k.todo_filters.normal.done,
    k.todo_filters.normal.waiting, k.todo_filters.normal.all,
    k.toggle_level_filter:gsub("[<>]", ""), k.toggle_sort:gsub("[<>]", ""))
  opts.open_picker          = T.open_all_headlines
  opts.allow_deletion       = false
  state.show_preview        = config.pickers.browse_headlines.preview
  opts.initial_mode         = config.pickers.browse_headlines.initial_mode
  opts.show_time            = false
  opts.allow_preview_toggle = true
  T.open_telescope_picker(opts)
end

return T
