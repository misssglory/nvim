-- plugin/lsp.lua

vim.lsp.config("*", {
    root_markers = { ".git" },
})

vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
    float = {
        style = "minimal",
        border = "rounded",
        source = "if_many",
        header = "",
        prefix = "",
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "✘",
            [vim.diagnostic.severity.WARN]  = "▲",
            [vim.diagnostic.severity.HINT]  = "⚑",
            [vim.diagnostic.severity.INFO]  = "»",
        },
    },
})

-- Ignore the specific rust-analyzer invalid offset spam
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
    if type(msg) == "string"
        and msg:match("^rust_analyzer: %-32603: Invalid offset LineCol")
    then
        return
    end
    return orig_notify(msg, level, opts)
end

local orig_open_float = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or "rounded"
    opts.max_width = opts.max_width or 80
    opts.max_height = opts.max_height or 24
    opts.wrap = opts.wrap ~= false
    return orig_open_float(contents, syntax, opts, ...)
end

local lsp_group = vim.api.nvim_create_augroup("my.lsp", { clear = true })
local lsp_highlight_group = vim.api.nvim_create_augroup("my.lsp.highlight", { clear = false })
local lsp_format_group = vim.api.nvim_create_augroup("my.lsp.format", { clear = false })

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
        local buf = ev.buf

        local map = function(mode, lhs, rhs, opts)
            opts = vim.tbl_extend("force", { buffer = buf, silent = true }, opts or {})
            vim.keymap.set(mode, lhs, rhs, opts)
        end

        map("n", "K", vim.lsp.buf.hover, { desc = "LSP Hover" })
        map("n", "gd", vim.lsp.buf.definition, { desc = "Goto definition" })
        map("n", "gD", vim.lsp.buf.declaration, { desc = "Goto declaration" })
        map("n", "gi", vim.lsp.buf.implementation, { desc = "Goto implementation" })
        map("n", "go", vim.lsp.buf.type_definition, { desc = "Goto type definition" })
        map("n", "gr", vim.lsp.buf.references, { desc = "References" })
        map("n", "gs", vim.lsp.buf.signature_help, { desc = "Signature help" })
        map("n", "gl", vim.diagnostic.open_float, { desc = "Line diagnostics" })

        map("n", "]d", function()
            vim.diagnostic.jump({ count = 1, float = true })
        end, { desc = "Next diagnostic" })

        map("n", "[d", function()
            vim.diagnostic.jump({ count = -1, float = true })
        end, { desc = "Prev diagnostic" })

        map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename" })
        map({ "n", "x" }, "<F3>", function()
            vim.lsp.buf.format({ async = true })
        end, { desc = "Format buffer" })
        map("n", "<F4>", vim.lsp.buf.code_action, { desc = "Code action" })
        map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })

        map("n", "<leader>xq", function()
            vim.diagnostic.setqflist({ open = true })
        end, { desc = "Diagnostics → quickfix" })

        map("n", "<leader>xe", function()
            vim.diagnostic.setqflist({
                open = true,
                severity = vim.diagnostic.severity.ERROR,
            })
        end, { desc = "Errors → quickfix" })

        map("n", "<leader>xx", function()
            vim.diagnostic.setloclist({ open = true })
        end, { desc = "Diagnostics → loclist" })

        if client:supports_method("textDocument/documentHighlight") then
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = lsp_highlight_group,
                buffer = buf,
                callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                group = lsp_highlight_group,
                buffer = buf,
                callback = vim.lsp.buf.clear_references,
            })
        end

        if client.name == "rust_analyzer" then
            -- Keep OFF by default; toggle only when needed
            vim.lsp.inlay_hint.enable(false, { bufnr = buf })

            map("n", "<leader>rh", function()
                local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
                vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
            end, { desc = "Toggle Rust inlay hints" })
        end

        local excluded_filetypes = {
            php = true,
            c = true,
            cpp = true,
        }

        if not client:supports_method("textDocument/willSaveWaitUntil")
            and client:supports_method("textDocument/formatting")
            and not excluded_filetypes[vim.bo[buf].filetype]
        then
            vim.api.nvim_clear_autocmds({
                group = lsp_format_group,
                buffer = buf,
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
                group = lsp_format_group,
                buffer = buf,
                callback = function()
                    vim.lsp.buf.format({
                        bufnr = buf,
                        id = client.id,
                        timeout_ms = 1000,
                    })
                end,
            })
        end
    end,
})

local caps = require("blink.cmp").get_lsp_capabilities()

vim.lsp.config("luals", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { { ".luarc.json", ".luarc.jsonc" }, ".git" },
    capabilities = caps,
    settings = {
        Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
                checkThirdParty = false,
                library = vim.api.nvim_get_runtime_file("", true),
            },
            telemetry = { enable = false },
        },
    },
})

vim.lsp.config("cssls", {
    cmd = { "vscode-css-language-server", "--stdio" },
    filetypes = { "css", "scss", "less" },
    root_markers = { "package.json", ".git" },
    capabilities = caps,
    settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
    },
})

vim.lsp.config("phpls", {
    cmd = { "intelephense", "--stdio" },
    filetypes = { "php" },
    root_markers = { "composer.json", ".git" },
    capabilities = caps,
    settings = {
        intelephense = {
            files = {
                maxSize = 5000000,
            },
        },
    },
})

vim.lsp.config("ts_ls", {
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = {
        "javascript", "javascriptreact", "javascript.jsx",
        "typescript", "typescriptreact", "typescript.tsx",
    },
    root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
    capabilities = caps,
    settings = {
        completions = {
            completeFunctionCalls = true,
        },
    },
})

vim.lsp.config("zls", {
    cmd = { "zls" },
    filetypes = { "zig", "zir" },
    root_markers = { "zls.json", "build.zig", ".git" },
    capabilities = caps,
    settings = {
        zls = {
            enable_build_on_save = true,
            build_on_save_step = "install",
            warn_style = false,
            enable_snippets = true,
        },
    },
})

vim.lsp.config("nil_ls", {
    cmd = { "nil" },
    filetypes = { "nix" },
    root_markers = { "flake.nix", "default.nix", ".git" },
    capabilities = caps,
    settings = {
        ["nil"] = {
            formatting = {
                command = { "alejandra" },
            },
        },
    },
})

vim.lsp.config("rust_analyzer", {
    cmd = { "rust-analyzer" },
    filetypes = { "rust" },
    root_markers = { "Cargo.toml", "rust-project.json", ".git" },
    capabilities = caps,
    settings = {
        ["rust-analyzer"] = {
            cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
            },
            checkOnSave = true,
            check = {
                command = "clippy",
            },
            procMacro = {
                enable = true,
            },
            inlayHints = {
                bindingModeHints = { enable = true },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "with_block" },
                discriminantHints = { enable = "fieldless" },
                expressionAdjustmentHints = { enable = "always" },
                implicitDrops = { enable = true },
                lifetimeElisionHints = {
                    enable = "skip_trivial",
                    useParameterNames = true,
                },
                parameterHints = { enable = true },
                reborrowHints = { enable = "always" },
                renderColons = true,
                typeHints = {
                    enable = true,
                    hideClosureInitialization = false,
                    hideNamedConstructor = false,
                },
            },
        },
    },
})

vim.lsp.config("clangd", {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=never",
        "--completion-style=detailed",
        "--query-driver=/nix/store/*-gcc-*/bin/gcc*,/nix/store/*-clang-*/bin/clang*,/run/current-system/sw/bin/cc*",
    },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    root_markers = { "compile_commands.json", ".clangd", "configure.ac", "Makefile", ".git" },
    capabilities = caps,
    init_options = {
        fallbackFlags = { "-std=c23" },
    },
})

vim.lsp.config("c3lsp", {
    cmd = { "c3-lsp" },
    filetypes = { "c3" },
    root_markers = { "project.json", ".git" },
    capabilities = caps,
})

vim.lsp.config("serve_d", {
    cmd = { "serve-d" },
    filetypes = { "d" },
    root_markers = { "dub.sdl", "dub.json", ".git" },
    capabilities = caps,
})

vim.lsp.config("jsonls", {
    cmd = { "vscode-json-languageserver", "--stdio" },
    filetypes = { "json", "jsonc" },
    root_markers = { "package.json", ".git", "config.jsonc" },
    capabilities = caps,
})

vim.lsp.config("hls", {
    cmd = { "haskell-language-server-wrapper", "--lsp" },
    filetypes = { "haskell", "lhaskell" },
    root_markers = { "stack.yaml", "cabal.project", "package.yaml", "*.cabal", "hie.yaml", ".git" },
    capabilities = caps,
    settings = {
        haskell = {
            formattingProvider = "fourmolu",
            plugin = {
                semanticTokens = { globalOn = false },
            },
        },
    },
})

vim.lsp.config("gopls", {
    cmd = { "gopls" },
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { "go.mod", "go.work", ".git" },
    capabilities = caps,
    settings = {
        gopls = {
            analyses = {
                unusedparams = false,
                ST1003 = false,
                ST1000 = false,
            },
            staticcheck = true,
        },
    },
})

vim.lsp.config("templ", {
    cmd = { "templ", "lsp" },
    filetypes = { "templ" },
    root_markers = { "go.mod", ".git" },
    capabilities = caps,
})

vim.filetype.add({
    extension = {
        h = "c",
        c3 = "c3",
        d = "d",
        templ = "templ",
    },
})

---@diagnostic disable-next-line: invisible
for name, _ in pairs(vim.lsp.config._configs) do
    if name ~= "*" then
        vim.lsp.enable(name)
    end
end
