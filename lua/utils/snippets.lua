-- Native snippets using vim.snippet (Neovim 0.10+).
-- Replaces LuaSnip + friendly-snippets (no plugins needed).

local M = {}

-- Common snippets by filetype.
-- Format: trigger -> snippet body ($1, $2, $0 for tab stops)
M.snippets = {
    lua = {
        ["func"] = "function ${1:name}(${2:args})\n\t$0\nend",
        ["if"] = "if $1 then\n\t$0\nend",
        ["for"] = "for ${1:i} = ${2:1}, ${3:10} do\n\t$0\nend",
        ["req"] = "local ${1:mod} = require()$0",
    },
    python = {
        ["def"] = "def ${1:name}(${2:args}):\n\t$0",
        ["if"] = "if $1:\n\t$0",
        ["for"] = "for ${1:x} in ${2:items}:\n\t$0",
        ["class"] = "class ${1:Name}:\n\tdef __init__(self$2):\n\t\t$0",
    },
    rust = {
        ["rpcshim"] = "use std::io::Write;\nuse std::os::unix::net::UnixStream;\n\n// Minimal Neovim msgpack-RPC client. Cargo.toml: rmp = \"1\", rmpv = \"1\", anyhow = \"1\"\n// Connect: nvim --headless --listen /tmp/nvim.sock\n\nfn rpc_call(stream: &mut UnixStream, msgid: u32, method: &str, params: rmpv::Value) -> anyhow::Result<rmpv::Value> {\n    let mut buf = Vec::new();\n    // request = [0, msgid, method, params]\n    rmp::encode::write_array_len(&mut buf, 4)?;\n    rmp::encode::write_u32(&mut buf, 0)?;\n    rmp::encode::write_u32(&mut buf, msgid)?;\n    rmp::encode::write_str(&mut buf, method)?;\n    rmpv::encode::write_value(&mut buf, &params)?;\n    stream.write_all(&buf)?;\n    // response = [1, msgid, error, result]\n    Ok(rmpv::decode::read_value(&mut stream.try_clone()?)?)\n}\n\nfn main() -> anyhow::Result<()> {\n    let sock = std::env::args().nth(1).unwrap_or_else(|| \"/tmp/nvim.sock\".into());\n    let mut stream = UnixStream::connect(&sock)?;\n    let resp = rpc_call(&mut stream, 1, \"${1:nvim_get_api_info}\", rmpv::Value::Array(vec![]))?;\n    println!(\"{resp:?}\");\n    $0\n    Ok(())\n}",
    },
    javascript = {
        ["func"] = "function ${1:name}(${2:args}) {\n\t$0\n}",
        ["if"] = "if ($1) {\n\t$0\n}",
        ["for"] = "for (let ${1:i} = 0; $1 < ${2:n}; $1++) {\n\t$0\n}",
    },
    wgsl = {
        ["frag"] = "@fragment\nfn ${1:fragment}(in: ${2:VertexOutput}) -> @location(0) vec4<f32> {\n\t$0\n}",
        ["vert"] = "@vertex\nfn ${1:vertex}(in: ${2:VertexInput}) -> ${3:VertexOutput} {\n\t$0\n}",
        ["uniform"] = "struct ${1:Name}Uniforms {\n\tcolor: vec4<f32>,\n\ttime: f32,\n\t_pad0: f32,\n\t_pad1: f32,\n\t_pad2: f32,\n};\n\n@group(${2:2}) @binding(0) var<uniform> uniforms: ${1:Name}Uniforms;",
        ["diag"] = "diagnostic(${1:off}, ${2:derivative_uniformity});",
        ["diagattr"] = "@diagnostic(${1:off}, ${2:derivative_uniformity})",
        ["enable"] = "enable ${1:f16};",
        ["requires"] = "requires ${1:unrestricted_pointer_parameters};",
    },
    wgsl_bevy = {
        ["frag"] = "#import bevy_sprite::mesh2d_vertex_output::VertexOutput\n\nstruct ${1:Name}Uniforms {\n\tcolor: vec4<f32>,\n\ttime: f32,\n\t_pad0: f32,\n\t_pad1: f32,\n\t_pad2: f32,\n};\n\n@group(2) @binding(0) var<uniform> uniforms: ${1:Name}Uniforms;\n\n@fragment\nfn fragment(mesh: VertexOutput) -> @location(0) vec4<f32> {\n\t$0\n}",
        ["uifrag"] = "#import bevy_ui::ui_vertex_output::UiVertexOutput\n\nstruct ${1:Name}Uniforms {\n\tcolor: vec4<f32>,\n\tprogress: f32,\n\t_pad0: f32,\n\t_pad1: f32,\n\t_pad2: f32,\n};\n\n@group(1) @binding(0) var<uniform> uniforms: ${1:Name}Uniforms;\n\n@fragment\nfn fragment(in: UiVertexOutput) -> @location(0) vec4<f32> {\n\t$0\n}",
        ["uniform"] = "struct ${1:Name}Uniforms {\n\tcolor: vec4<f32>,\n\ttime: f32,\n\t_pad0: f32,\n\t_pad1: f32,\n\t_pad2: f32,\n};",
    },
}

---Expand snippet at cursor if trigger matches.
function M.expand_or_jump()
    if vim.snippet.active({ direction = 1 }) then
        vim.snippet.jump(1)
        return true
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before = line:sub(1, col)
    local trigger = before:match("(%S+)$")

    if trigger then
        local ft = vim.bo.filetype
        local ft_snippets = M.snippets[ft] or {}
        local body = ft_snippets[trigger]
        if body then
            -- Delete trigger and expand
            local start_col = col - #trigger
            vim.api.nvim_buf_set_text(0, vim.api.nvim_win_get_cursor(0)[1] - 1, start_col, vim.api.nvim_win_get_cursor(0)[1] - 1, col, { "" })
            vim.snippet.expand(body)
            return true
        end
    end
    return false
end

---Jump to previous snippet placeholder.
function M.jump_back()
    if vim.snippet.active({ direction = -1 }) then
        vim.snippet.jump(-1)
        return true
    end
    return false
end

---Setup keymaps for snippet expansion.
function M.setup()
    vim.keymap.set({ "i", "s" }, "<Tab>", function()
        if not M.expand_or_jump() then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
        end
    end, { desc = "Expand snippet or jump forward" })

    vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
        if not M.jump_back() then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true), "n", false)
        end
    end, { desc = "Jump to previous snippet placeholder" })
end

return M
