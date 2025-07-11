local U = require("org-telescope.util")
local M = {}

local S = { list = {} }

local function load() S.list = U.read_json(config.history_file, {}) end
local function save() U.write_json(config.history_file, S.list) end

-- ---------------------------------------------------------------------
function M.add(file, line, hl)
  for _, e in ipairs(S.list) do
    if e.file == file and e.line == line and e.text == hl.text then
      e.time = os.date("%Y-%m-%d %H:%M:%S"); return save()
    end
  end
  table.insert(S.list, {
    file = file,
    line = line,
    time = os.date("%Y-%m-%d %H:%M:%S"),
    text = hl.text,
    level = hl.level,
    todo_state = hl.todo_state,
    headline_text = hl.headline_text
  })
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
