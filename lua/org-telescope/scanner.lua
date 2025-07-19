local U = require("org-telescope.util")
local H = require("org-telescope.headline")
local S = {}

local function include_file(path)
  if not path:match("%.org$") then return false end
  for _, ex in ipairs(config.exclude_files) do
    if path == ex or vim.fn.fnamemodify(path, ":t") == ex then return false end
  end
  return true
end

local function gather_files()
  local files = {}
  if config.org_folder then
    local cmd = "find " .. vim.fn.shellescape(vim.fn.expand(config.org_folder)) .. " -name '*.org'"
    local h = io.popen(cmd); if not h then return files end
    for f in h:lines() do if include_file(f) then table.insert(files, f) end end
    h:close()
  else
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local n = vim.api.nvim_buf_get_name(b); if include_file(n) then table.insert(files, n) end
    end
  end
  return files
end

function S.scan()
  local res = {}
  for _, file in ipairs(gather_files()) do
    for i, l in ipairs(vim.fn.readfile(file)) do
      local lvl, todo, text = H.parse(l)
      if lvl then
        table.insert(res, {
          file = file,
          line = i,
          text = (todo and (todo .. " " .. text) or text),
          level = lvl,
          todo_state = todo,
          headline_text = text,
        })
      end
    end
  end
  return res
end

return S
