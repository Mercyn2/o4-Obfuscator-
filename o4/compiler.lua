-- Compiles a Lua script to bytecode using luac
local compiler = {}
local os = os
local io = io

function compiler.compile(script)
    local tmp_in  = os.tmpname() .. ".lua"
    local tmp_out = os.tmpname() .. ".out"

    local f = io.open(tmp_in, "w")
    if not f then error("Cannot open temp file for writing") end
    f:write(script)
    f:close()

    local ret = os.execute("luac -o " .. tmp_out .. " " .. tmp_in .. " 2>/dev/null")
    os.remove(tmp_in)

    if ret ~= 0 and ret ~= true then
        os.remove(tmp_out)
        error("luac compilation failed - check your script for syntax errors")
    end

    local of = io.open(tmp_out, "rb")
    if not of then error("Cannot open compiled output") end
    local bytecode = of:read("*a")
    of:close()
    os.remove(tmp_out)

    return bytecode
end

return compiler
