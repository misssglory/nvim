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

-- Load wff extension with better error handling
local function load_wff_extension()
    local ok, err = pcall(function()
        -- Ensure the extension file is loaded
        local wff_ext = require("telescope._extensions.wff")
        if wff_ext and wff_ext.name == "wff" then
            vim.schedule(function()
                vim.notify("WFF extension loaded successfully", vim.log.levels.INFO)
            end)
        end
    end)
    if not ok then
        vim.schedule(function()
            vim.notify("Failed to load wff extension: " .. tostring(err), vim.log.levels.ERROR)
        end)
    end
end

load_wff_extension()

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files)
vim.keymap.set("n", "<leader>fo", builtin.oldfiles)
vim.keymap.set("n", "<leader>fq", builtin.quickfix)
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fg", function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)
vim.keymap.set("n", "<leader>fc", function()
    builtin.grep_string({ search = vim.fn.expand("%:t:r") })
end, { desc = "Find current file" })
vim.keymap.set("n", "<leader>fs", function()
    builtin.grep_string({})
end, { desc = "Find current string" })
vim.keymap.set("n", "<leader>fi", function()
    builtin.find_files({ cwd = "~/.config/nvim/" })
end)

-- WFF keybindings - try both methods
vim.keymap.set("n", "<leader>fw", function()
    -- Try to get the extension from telescope
    local telescope = require("telescope")
    if telescope.extensions and telescope.extensions.wff and telescope.extensions.wff.wff then
        telescope.extensions.wff.wff()
    else
        -- Try direct require
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