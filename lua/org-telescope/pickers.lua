local M = {}

function M.highlight_groups()
  vim.api.nvim_exec([[
    highlight default OrgTodoRed     guifg=#FF5555 gui=bold
    highlight default OrgProgress    guifg=#FFAA00 gui=bold
    highlight default OrgDone        guifg=#50FA7B gui=bold
    highlight default OrgWaiting     guifg=#BD93F9 gui=bold
  ]], false)
end

function M.custom_previewer()
  local previewers = require("telescope.previewers")
  return previewers.new_buffer_previewer {
    title = "Org Headline Preview",
    get_buffer_by_name = function(_, entry) return entry.value.file end,
    define_preview = function(self, entry)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
      local path, ln = entry.value.file, entry.value.line or 1
      if not vim.loop.fs_stat(path) then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "File not found: " .. path })
        return
      end
      local ok, lines = pcall(vim.fn.readfile, path)
      if not ok then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "Error reading: " .. path })
        return
      end
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", vim.fn.fnamemodify(path, ":e"))
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      local win = self.state.winid
      if win and vim.api.nvim_win_is_valid(win) then
        local safe = math.min(math.max(1, ln), #lines)
        pcall(vim.api.nvim_win_set_cursor, win, { safe, 0 })
        vim.api.nvim_win_call(win, function() vim.cmd("normal! zz") end)
      end
      vim.api.nvim_win_set_option(win, "cursorline", true)
      vim.api.nvim_win_set_option(win, "cursorlineopt", "line")
    end
  }
end

return M
