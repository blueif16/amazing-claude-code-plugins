-- CloudMate Neovim Config
-- Minimal setup for watching agents modify files across worktrees.
--
-- Install: copy to ~/.config/nvim/lua/cloudmate.lua
-- Then add to your init.lua: require("cloudmate")
--
-- Dependencies (install via lazy.nvim, packer, or manually):
--   telescope.nvim + telescope-fzf-native (fuzzy finding)
--   gitsigns.nvim (inline git diff indicators)
--   Optional: fugitive.vim (git commands inside nvim)

-- Auto-reload files when agents modify them externally
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = "checktime",
})

-- Faster CursorHold for quicker file-change detection (default 4000ms)
vim.o.updatetime = 300

-- Find files across all active worktrees
vim.keymap.set("n", "<leader>fw", function()
  local worktrees = vim.fn.systemlist("git worktree list --porcelain | grep '^worktree' | cut -d' ' -f2-")
  if #worktrees == 0 then
    worktrees = { vim.fn.getcwd() }
  end
  require("telescope.builtin").find_files({ search_dirs = worktrees })
end, { desc = "Find files across all worktrees" })

-- Grep across all active worktrees
vim.keymap.set("n", "<leader>gw", function()
  local worktrees = vim.fn.systemlist("git worktree list --porcelain | grep '^worktree' | cut -d' ' -f2-")
  if #worktrees == 0 then
    worktrees = { vim.fn.getcwd() }
  end
  require("telescope.builtin").live_grep({ search_dirs = worktrees })
end, { desc = "Grep across all worktrees" })

-- Quick access to plan.md
vim.keymap.set("n", "<leader>cp", function()
  local plan = vim.fn.findfile(".tasks/plan.md", ".;")
  if plan ~= "" then
    vim.cmd("edit " .. plan)
  else
    print("No .tasks/plan.md found")
  end
end, { desc = "Open CloudMate plan" })

-- Gitsigns setup (shows inline diffs as agents write code)
local ok, gitsigns = pcall(require, "gitsigns")
if ok then
  gitsigns.setup({
    signs = {
      add = { text = "│" },
      change = { text = "│" },
      delete = { text = "_" },
    },
    -- Watch for file changes from other processes (agents)
    watch_gitdir = { interval = 1000, follow_files = true },
  })
end
