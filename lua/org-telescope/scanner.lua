local U = require("org-telescope.util")
local H = require("org-telescope.headline")
local S = {}


local function gather_files()
  local files = {}
  if config.org_folder then
    local cmd = "find " .. vim.fn.shellescape(vim.fn.expand(config.org_folder)) .. " -name '*.org'"
    local h = io.popen(cmd); if h then
      for f in h:lines() do if U.file_in_scope(f) then table.insert(files, f) end end
      h:close()
    end
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local n = vim.api.nvim_buf_get_name(b)
      if n ~= '' then n = vim.fn.fnamemodify(n, ':p') end
      if U.file_in_scope(n) and not vim.tbl_contains(files, n) then
        table.insert(files, n)
      end
    end
  else
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local n = vim.api.nvim_buf_get_name(b)
      if n ~= '' then n = vim.fn.fnamemodify(n, ':p') end
      if U.file_in_scope(n) then table.insert(files, n) end
    end
  end
  return files
end

function S.scan()
  local res = {}
  for _, file in ipairs(gather_files()) do
    if vim.fn.filereadable(file) == 1 then
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
  end
  return res
end

return S
