local U = require("org-telescope.util")
local M = {}

local S = { list = {} }

local function load() S.list = U.read_json(config.history.history_file, {}) end
local function save() U.write_json(config.history.history_file, S.list) end

-- ---------------------------------------------------------------------
-- utils ----------------------------------------------------------
local function now_ms()
  return string.format("%s.%03d",
    os.date("%Y-%m-%d %H:%M:%S"),
    math.floor(vim.loop.hrtime() / 1e6) % 1000)
end

local function same(e, f, l, t)
  return e.file == f and e.line == l and e.text == t
end

-- main -----------------------------------------------------------
function M.add(file, line, hl)
  local newest = {
    file = file,
    line = line,
    text = hl.text,
    time = now_ms(),
    level = hl.level,
    todo_state = hl.todo_state,
    headline_text = hl.headline_text,
  }

  -- 1️⃣ update *all* duplicates in-place
  local first_seen = nil
  local i = 1
  while i <= #S.list do
    if same(S.list[i], file, line, hl.text) then
      S.list[i] = newest
      if first_seen then
        -- drop extra dupes
        table.remove(S.list, i)
      else
        first_seen = true
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  -- 2️⃣ nothing matched → append
  if not first_seen then
    table.insert(S.list, newest)
  end

  -- 3️⃣ sort newest-first (optional)
  table.sort(S.list, function(a, b) return a.time < b.time end)

  save()
end

function M.delete_one(idx)
  if S.list[idx] then
    table.remove(S.list, idx); save(); return true
  end
end

function M.delete_multiple(indices)
  table.sort(indices, function(a, b) return a > b end)
  for _, i in ipairs(indices) do if S.list[i] then table.remove(S.list, i) end end
  save(); return true
end

function M.clear()
  S.list = {}; save()
end

function M.reload()
  load()
end

function M.all() return S.list end

function M.jump(entry)
  vim.cmd("edit " .. vim.fn.fnameescape(entry.file))
  vim.api.nvim_win_set_cursor(0, { entry.line, 0 }); vim.cmd("normal! zz")
end

function M.prune()
  local pruned = {}
  for _, e in ipairs(S.list) do
    if vim.fn.filereadable(e.file) == 1 then
      local lines = vim.fn.readfile(e.file)
      local line = lines[e.line]
      if line and line:match(vim.pesc(e.text)) then
        table.insert(pruned, e)
      end
    end
  end
  S.list = pruned
  save()
  print("[org-telescope] Pruned invalid entries", vim.log.levels.INFO)
end

load()

return M
