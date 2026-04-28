-- ~/nixos-dotfiles/config/nvim/lua/telescope/_extensions/wff.lua
-- WFF Extension for Telescope

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
    vim.notify("telescope.nvim not found", vim.log.levels.ERROR)
    return {}  -- Return empty table instead of nil
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

-- Parse wff JSON output
local function parse_wff_output(output)
    local results = {}
    for line in output:gmatch("[^\r\n]+") do
        if line ~= "" then
            local ok, parsed = pcall(vim.json.decode, line)
            if ok and parsed then
                local icon = ""
                if parsed.type == "Function" then
                    icon = "ƒ"
                elseif parsed.type == "Struct" then
                    icon = "Ⓢ"
                elseif parsed.type == "Impl" then
                    icon = "ℑ"
                end
                
                table.insert(results, {
                    filename = parsed.path,
                    lnum = parsed.line,
                    end_lnum = parsed.end_line,
                    text = string.format("%s %s (%s:%d)",
                        icon,
                        parsed.name,
                        vim.fn.fnamemodify(parsed.path, ":t"),
                        parsed.line
                    ),
                    type = parsed.type,
                    name = parsed.name,
                    path = parsed.path,
                    start_line = parsed.line,
                    end_line = parsed.end_line,
                })
            end
        end
    end
    return results
end

-- WFF Picker function
local function wff_picker(opts)
    opts = opts or {}
    local directory = opts.directory or vim.fn.getcwd()
    
    -- Check if wff is available
    local wff_check = vim.fn.executable("wff")
    if wff_check == 0 then
        vim.schedule(function()
            vim.notify("wff not found. Install with: cargo install wcc", vim.log.levels.ERROR)
        end)
        return
    end
    
    -- Run wff command
    local command = string.format("wff --telescope %s 2>/dev/null", vim.fn.shellescape(directory))
    
    vim.system({ "bash", "-c", command }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code ~= 0 then
                vim.notify("No code blocks found in " .. directory, vim.log.levels.WARN)
                return
            end
            
            if not obj.stdout or obj.stdout == "" then
                vim.notify("No structs, impls, or functions found", vim.log.levels.WARN)
                return
            end
            
            local results = parse_wff_output(obj.stdout)
            
            if #results == 0 then
                vim.notify("No structs, impls, or functions found", vim.log.levels.WARN)
                return
            end
            
            -- Create previewer
            local previewer = previewers.new_buffer_previewer({
                title = "Code Preview",
                define_preview = function(self, entry)
                    if not entry or not entry.value then
                        return
                    end
                    
                    local value = entry.value
                    local bufnr = self.state.bufnr
                    
                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
                    
                    local ext = vim.fn.fnamemodify(value.filename, ":e")
                    local ft = ext == "rs" and "rust" or ext
                    pcall(vim.api.nvim_buf_set_option, bufnr, 'filetype', ft)
                    
                    local lines = vim.fn.readfile(value.filename)
                    local start_line = value.start_line
                    local end_line = value.end_line
                    
                    if start_line and end_line and lines and #lines > 0 then
                        local preview_lines = {}
                        for i = start_line - 1, math.min(end_line - 1, #lines - 1) do
                            local line_num = i + 1
                            local line_content = lines[i] or ""
                            table.insert(preview_lines, string.format("%4d %s", line_num, line_content))
                        end
                        if #preview_lines > 0 then
                            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, preview_lines)
                            pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, "TelescopePreviewLine", 0, 0, -1)
                        else
                            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Unable to preview code block" })
                        end
                    else
                        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Unable to preview code block" })
                    end
                end,
            })
            
            -- Create picker
            pickers.new(opts, {
                prompt_title = "Rust Code Blocks (wff)",
                finder = finders.new_table({
                    results = results,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry.text,
                            ordinal = string.format("%s %s", entry.type, entry.name),
                            filename = entry.filename,
                            lnum = entry.lnum,
                        }
                    end,
                }),
                previewer = previewer,
                sorter = conf.generic_sorter(opts),
                attach_mappings = function(prompt_bufnr, map)
                    local jump_to_block = function()
                        local selection = action_state.get_selected_entry()
                        if not selection or not selection.value then
                            return
                        end
                        
                        actions.close(prompt_bufnr)
                        
                        local entry = selection.value
                        local file_path = entry.filename
                        local line_number = entry.start_line
                        
                        vim.cmd(string.format("edit +%d %s", line_number, vim.fn.fnameescape(file_path)))
                        vim.cmd("normal! zz")
                    end
                    
                    map("i", "<CR>", jump_to_block)
                    map("n", "<CR>", jump_to_block)
                    
                    return true
                end,
            }):find()
        end)
    end)
end

-- Register the extension and return it properly
local extension = {
    name = "wff",
    exports = {
        wff = wff_picker,
    },
}

-- Register with telescope
telescope.register_extension(extension)

-- Return the extension (not a boolean)
return extension