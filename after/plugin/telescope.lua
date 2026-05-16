-- after/plugin/telescope.lua
local actions = require("telescope.actions")

require("telescope").setup({
    defaults = {
        mappings = {
            i = {
                ["<C-k>"] = actions.move_selection_previous,
                ["<C-j>"] = actions.move_selection_next,
                ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
            },
        },
    },
})

local function load_wff_extension()
    local ok, err = pcall(function()
        local wff_ext = require("telescope._extensions.wff")
        if wff_ext and wff_ext.name == "wff" then
            vim.schedule(function()
                vim.notify("WFF extension loaded successfully", vim.log.levels.INFO)
            end)
        end
    end)

    if not ok then
        vim.schedule(function()
            vim.notify("Failed to load WFF extension: " .. tostring(err), vim.log.levels.ERROR)
        end)
    end
end

load_wff_extension()

local builtin = require("telescope.builtin")

local function open_fff_files_or_telescope()
    local ok, fff = pcall(require, "fff")
    if ok and fff and fff.find_files then
        local call_ok, err = pcall(fff.find_files)
        if call_ok then
            return
        end
        vim.notify("fff find_files failed, falling back to Telescope: " .. tostring(err), vim.log.levels.WARN)
    end

    builtin.find_files()
end

-- FFF for files
vim.keymap.set("n", "<leader>ff", open_fff_files_or_telescope, {
    desc = "Find files (FFF, fallback Telescope)",
})

-- Oldfiles, buffers, etc
vim.keymap.set("n", "<leader>fo", builtin.oldfiles)
vim.keymap.set("n", "<leader>fq", builtin.quickfix)
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })

-- Whole-repo text search using rg
vim.keymap.set("n", "<leader>fs", function()
    builtin.live_grep({})
end, { desc = "Search text in project (rg)" })

-- Prompted grep
vim.keymap.set("n", "<leader>fg", function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)

-- Grep for current filename stem
vim.keymap.set("n", "<leader>fc", function()
    builtin.grep_string({ search = vim.fn.expand("%:t:r") })
end, { desc = "Find current file name" })

-- Config files
vim.keymap.set("n", "<leader>fi", function()
    builtin.find_files({ cwd = "~/.config/nvim/" })
end)

-- WFF bindings (unchanged)
vim.keymap.set("n", "<leader>fw", function()
    local telescope = require("telescope")
    if telescope.extensions and telescope.extensions.wff and telescope.extensions.wff.wff then
        telescope.extensions.wff.wff()
    else
        local ok, wff = pcall(require, "telescope._extensions.wff")
        if ok and wff and wff.exports and wff.exports.wff then
            wff.exports.wff()
        else
            vim.schedule(function()
                vim.notify("WFF extension not available", vim.log.levels.ERROR)
            end)
        end
    end
end, { desc = "Find Rust code blocks (wff)" })

vim.keymap.set("n", "<leader>fW", function()
    local dir = vim.fn.input("Directory: ", vim.fn.getcwd(), "dir")
    if dir ~= "" then
        local telescope = require("telescope")
        if telescope.extensions and telescope.extensions.wff and telescope.extensions.wff.wff then
            telescope.extensions.wff.wff({ directory = dir })
        else
            local ok, wff = pcall(require, "telescope._extensions.wff")
            if ok and wff and wff.exports and wff.exports.wff then
                wff.exports.wff({ directory = dir })
            else
                vim.schedule(function()
                    vim.notify("WFF extension not available", vim.log.levels.ERROR)
                end)
            end
        end
    end
end, { desc = "Find Rust code blocks in specific directory" })