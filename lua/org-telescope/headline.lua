local H = {}

function H.parse(line)
  local stars, body = line:match("^(%*+)%s+(.+)")
  if not stars or #stars > config.history.max_headline_level then return end
  local todo, rest = body:match("^(%S+)%s+(.+)")
  for _, kw in ipairs(config.todo_keywords) do
    if todo == kw then return #stars, todo, rest end
  end
  return #stars, nil, body
end

function H.current()
  local lvl, todo, text = H.parse(vim.api.nvim_get_current_line() or "")
  if not lvl then return end
  return {
    level = lvl,
    todo_state = todo,
    headline_text = text,
    text = (todo and (todo .. " " .. text) or text)
  }
end

return H
