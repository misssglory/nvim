-- after/plugin/fff.lua
local plugin_root = vim.fn.stdpath("data") .. "/plugins/fff.nvim"

local function fff_binary_exists()
    local candidates = {
        plugin_root .. "/target/release/libfff_nvim.so",
        plugin_root .. "/target/release/fff_nvim.so",
    }

    for _, path in ipairs(candidates) do
        if vim.uv.fs_stat(path) then
            return true
        end
    end

    return false
end

local function ensure_fff_backend()
    if fff_binary_exists() then
        return
    end

    local ok_download, download = pcall(require, "fff.download")
    if not ok_download then
        vim.schedule(function()
            vim.notify("fff.download module not available", vim.log.levels.ERROR)
        end)
        return
    end

    vim.schedule(function()
        vim.notify("fff.nvim backend missing, downloading/building it now...", vim.log.levels.INFO)
    end)

    local ok, err = pcall(download.download_or_build_binary)
    if not ok then
        vim.schedule(function()
            vim.notify("fff.nvim backend install failed: " .. tostring(err), vim.log.levels.ERROR)
        end)
        return
    end

    vim.schedule(function()
        vim.notify("fff.nvim backend installed. Restart Neovim.", vim.log.levels.INFO)
    end)
end

ensure_fff_backend()

local ok, fff = pcall(require, "fff")
if not ok then
    return
end

fff.setup({
    lazy_sync = true,
    debug = {
        enabled = false,
        show_scores = false,
    },
    logging = {
        enabled = true,
        log_file = vim.fn.stdpath("log") .. "/fff.log",
        log_level = "info",
    },
})