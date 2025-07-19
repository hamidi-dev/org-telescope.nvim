-- org-telescope – Refile-Modul (self-contained) --------------------------
local scanner       = require("org-telescope.scanner")
local headline      = require("org-telescope.headline")
local util          = require("org-telescope.util")
local customPickers = require("org-telescope.pickers")

local R             = {}

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function include_file(path)
  if not path:match("%.org$") then return false end
  for _, ex in ipairs(config.exclude_files or {}) do
    if path == ex or vim.fn.fnamemodify(path, ":t") == ex then return false end
  end
  return true
end

-- rekursiv alle .org-Dateien einsammeln (ohne externe Tools)
local function scandir(dir, out)
  for name, t in vim.fs.dir(dir) do
    local p = dir .. "/" .. name
    if t == "file" and include_file(p) then
      table.insert(out, p)
    elseif t == "directory" then
      scandir(p, out)
    end
  end
end

local function gather_files()
  local files = {}
  if config.org_folder then
    scandir(vim.fn.expand(config.org_folder), files)
  else
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local n = vim.api.nvim_buf_get_name(b)
      if include_file(n) then table.insert(files, n) end
    end
  end
  local seen, uniq = {}, {}
  for _, f in ipairs(files) do
    if not seen[f] then
      uniq[#uniq + 1] = f
      seen[f] = true
    end
  end
  return uniq
end

-- Bereich des aktuellen Headings ermitteln (Cursor darf überall stehen)
local function heading_range(lines, pos)
  local start = pos
  while start > 0 and not lines[start]:match("^%*+") do
    start = start - 1
  end
  if start == 0 then return nil end

  local lvl = #(lines[start]:match("^(%*+)"))
  local stop = #lines
  for i = start + 1, #lines do
    local s = lines[i]:match("^(%*+)")
    if s and #s <= lvl then
      stop = i - 1; break
    end
  end
  return start, stop, lvl
end

local function adjust_levels(seg, diff)
  if diff == 0 then return seg end
  local res = {}
  for _, l in ipairs(seg) do
    local stars, rest = l:match("^(%*+)(.*)")
    if stars then
      table.insert(res, string.rep("*", #stars + diff) .. rest)
    else
      table.insert(res, l)
    end
  end
  return res
end

-- Buffers neu laden, falls offen & unmodifiziert
local function reload_if_open(path)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b) == path
        and not vim.api.nvim_buf_get_option(b, "modified") then
      vim.api.nvim_buf_call(b, function() vim.cmd("edit!") end)
      break
    end
  end
end

-- Segment ausschneiden & woanders einfügen
local function move_segment(src, s_line, e_line, target_file, insert_pos, diff)
  local lines   = vim.fn.readfile(src)
  local segment = vim.list_slice(lines, s_line, e_line)
  for i = e_line, s_line, -1 do table.remove(lines, i) end
  vim.fn.writefile(lines, src)

  local tlines = vim.fn.readfile(target_file)
  segment      = adjust_levels(segment, diff)
  insert_pos   = insert_pos or (#tlines + 1)
  for i, l in ipairs(segment) do
    table.insert(tlines, insert_pos + i - 1, l)
  end
  vim.fn.writefile(tlines, target_file)

  reload_if_open(src)
  reload_if_open(target_file)
end

------------------------------------------------------------------------
-- Haupt­funktion
------------------------------------------------------------------------
function R.refile_current_heading(mode)
  ----------------------------------------------------------------------
  -- 1) aktuellen Abschnitt bestimmen
  ----------------------------------------------------------------------
  local buf       = vim.api.nvim_get_current_buf()
  local file      = vim.api.nvim_buf_get_name(buf)
  local cur       = vim.api.nvim_win_get_cursor(0)[1]
  local lines     = vim.fn.readfile(file)

  local s, e, lvl = heading_range(lines, cur)
  if not s then return util.log("Not inside an Org heading", vim.log.levels.WARN) end

  -- Infos des Headings für spätere Berechnungen
  local _, todo_kw, txt                                         = headline.parse(lines[s])
  local cur_heading                                             = {
    level         = lvl,
    todo_state    = todo_kw,
    headline_text = txt,
    text          = (todo_kw and (todo_kw .. " " .. txt) or txt),
  }

  ----------------------------------------------------------------------
  -- 2) Picker-Daten vorbereiten
  ----------------------------------------------------------------------
  mode                                                          = mode or config.refile.default_mode or "file"
  local all_headlines                                           = scanner.scan()
  local files                                                   = gather_files()

  local telescope_pickers, finders, conf, actions, action_state =
      require("telescope.pickers"),
      require("telescope.finders"),
      require("telescope.config").values,
      require("telescope.actions"),
      require("telescope.actions.state")
  customPickers.highlight_groups()

  local function make_file_entries()
    local tbl = {}
    for i, f in ipairs(files) do
      tbl[i] = {
        value = { file = f, line = 1 },
        display = vim.fn.fnamemodify(f, ":t"),
        ordinal = f,
      }
    end
    return tbl
  end

  local function make_headline_entries()
    local tbl = {}
    for i, h in ipairs(all_headlines) do
      local indent = string.rep("  ", h.level - 1)
      tbl[i] = {
        value   = h,
        display = indent .. h.text .. " (" .. vim.fn.fnamemodify(h.file, ":t") .. ")",
        ordinal = h.text .. " " .. h.file,
      }
    end
    return tbl
  end

  ----------------------------------------------------------------------
  -- 3) Picker erstellen & anzeigen
  ----------------------------------------------------------------------
  local function build_picker(entries, title)
    return telescope_pickers.new({
      initial_mode = config.pickers.refile.initial_mode,
      prompt_title = title,
    }, {
      finder = finders.new_table {
        results = entries,
        entry_maker = function(e)
          return { value = e.value, display = e.display, ordinal = e.ordinal }
        end,
      },
      sorter = conf.generic_sorter({}),
      previewer = config.pickers.refile.preview and customPickers.custom_previewer() or nil,
      attach_mappings = function(bufnr, map)
        -- zwischen Datei- & Headline-Mode umschalten
        local function toggle()
          actions.close(bufnr)
          R.refile_current_heading(mode == "file" and "heading" or "file")
        end
        map("i", "<C-Space>", toggle)
        map("n", "<C-Space>", toggle)

        -- Auswahl übernehmen
        actions.select_default:replace(function()
          local sel = action_state.get_selected_entry()
          actions.close(bufnr)
          if mode == "file" then
            move_segment(file, s, e, sel.value.file, nil, 0)
          else
            local tlines = vim.fn.readfile(sel.value.file)
            local _, tstop = heading_range(tlines, sel.value.line)
            move_segment(
              file, s, e, sel.value.file,
              tstop + 1,
              sel.value.level + 1 - lvl
            )
          end
        end)
        return true
      end,
    })
  end

  local picker = (mode == "file")
      and build_picker(make_file_entries(), "Select Target File")
      or build_picker(make_headline_entries(), "Select Target Heading")
  picker:find()
end

return R
