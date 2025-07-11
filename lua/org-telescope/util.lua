local U = {}

function U.log(msg, lvl)
  if config.debug or lvl == vim.log.levels.ERROR then
    vim.notify("[org-telescope] " .. msg, lvl or vim.log.levels.INFO)
  end
end

local function warn(msg) vim.notify("[org-telescope] " .. msg, vim.log.levels.WARN) end
local function err(msg) vim.notify("[org-telescope] " .. msg, vim.log.levels.ERROR) end

function U.ensure_dir(p)
  local d = vim.fn.fnamemodify(p, ":h")
  if vim.fn.isdirectory(d) == 0 then vim.fn.mkdir(d, "p") end
end

function U.read_json(path, fallback)
  local f = io.open(path, "r")
  if not f then return fallback end

  local content = f:read("*a"); f:close()

  if content:sub(1, 3) == "\239\187\191" then content = content:sub(4) end

  local ok, data = pcall(vim.fn.json_decode, content)
  if ok and type(data) == "table" then return data end

  warn("Could not decode " .. path .. "; keeping previous file and starting fresh")
  local backup = path .. ".corrupt-" .. os.date("%Y%m%d%H%M%S")
  local bf = io.open(backup, "w"); if bf then
    bf:write(content); bf:close()
  end
  return fallback
end

function U.write_json(path, tbl)
  U.ensure_dir(path)
  local tmp = path .. ".tmp"
  local enc = vim.fn.json_encode(tbl or {})

  local f, e = io.open(tmp, "w")
  if not f then return err("IO error: " .. e) end
  f:write(enc); f:close()

  os.remove(path) -- ignoriert Fehler
  local ok, mv = pcall(os.rename, tmp, path)
  if not ok then err("Could not rename " .. tmp .. " → " .. path .. ": " .. tostring(mv)) end
end

return U
