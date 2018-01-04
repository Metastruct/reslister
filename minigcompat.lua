file = io
io.Open = function(a, b) return io.open(a, b) end
local File = debug.getmetatable(io.stdin)

function File:Tell()
    return self:seek("cur", 0)
end

function File:Seek(p)
    return self:seek("set", p)
end

function File:Read(n)
    return self:read(n)
end

function File:Size()
    local pos = self:Tell()
    local sz = self:seek("end")
    self:seek("set", pos)

    return sz
end

local tmp = {}

function File.ReadString(f, n, ch)
    n = n or 256
    ch = ch or '\0'
    local startpos = f:Tell()
    local offset = 0
    local tmpn = 0
    local sz = f:Size()

    --TODO: Use n and sz instead
    for i = 1, 1048576 do
        --	while true do
        if f:Tell() >= sz then return nil, "eof" end
        local str = f:Read(n)
        --if not str then return nil,"eof","wtf" end
        local pos = str:find(ch, 1, true)

        if pos then
            --offset = offset + pos
            --reset position
            f:Seek(startpos + offset + pos)
            tmp[tmpn + 1] = str:sub(1, pos - 1)

            return table.concat(tmp, '', 1, tmpn + 1)
        else
            tmpn = tmpn + 1
            tmp[tmpn] = str
            offset = offset + n
        end
    end

    return nil, "not found"
end

local vstruct = require 'vstruct'
local fmt = vstruct.compile("f4")

function File.ReadFloat(f)
    return fmt:read(f, t)[0]
end

local meta = debug.getmetatable
local string = debug.getmetatable''

function isstring(s)
    return meta(s) == string
end

function isnumber(s)
    return type(s) == 'number'
end

function istable(s)
    return type(s) == 'table'
end