local ok, blink = pcall(require, "blink.cmp")
if not ok then
    return
end

blink.setup({
    keymap = {
        -- a simple super-tab style mapping
        preset = "super-tab",
        -- you can add explicit overrides here later if needed
    },
    appearance = {
        -- this makes blink’s look similar to nvim-cmp’s defaults
        use_nvim_cmp_as_default = true,
    },
    completion = {
        -- don’t auto-show docs to keep it quiet
        documentation = {
            auto_show = false,
        },
    },
    sources = {
        -- default sources for each filetype
        default = { "lsp", "path", "snippets", "buffer" },
    },
})