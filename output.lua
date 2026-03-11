--[[
    obf_core.lua — Roblox + Lua 5.1 compatible obfuscation engine
    Clean double-layer XOR encoding, no junk injection (avoids parser errors)
--]]

local obf = {}

-- ─────────────────────────────────────────────
-- BUILD-TIME XOR (runs on your PC, Lua 5.1)
-- ─────────────────────────────────────────────

local function bxor(a, b)
    if bit then return bit.bxor(a, b) end
    local r, m = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then r = r + m end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        m = m * 2
    end
    return r
end

math.randomseed(os.time())

-- ─────────────────────────────────────────────
-- UTILITIES
-- ─────────────────────────────────────────────

local function randomKey(len)
    local t = {}
    for i = 1, len do t[i] = math.random(1, 254) end
    return t
end

local function xorBytes(str, key)
    local result = {}
    local klen = #key
    for i = 1, #str do
        result[i] = bxor(str:byte(i), key[((i - 1) % klen) + 1])
    end
    return result
end

local function keyToString(key)
    local t = {}
    for i, v in ipairs(key) do t[i] = tostring(v) end
    return "{" .. table.concat(t, ",") .. "}"
end

local function bytesToLiteral(bytes)
    local t = {}
    for i, v in ipairs(bytes) do t[i] = tostring(v) end
    return "{" .. table.concat(t, ",") .. "}"
end

-- ─────────────────────────────────────────────
-- RUNTIME XOR — embedded into the output file
-- Supports: Roblox (bit32), LuaJIT (bit), plain Lua 5.1 (fallback)
-- ─────────────────────────────────────────────

local RUNTIME_XOR = [[local function __xor(a,b)
  if bit32 then return bit32.bxor(a,b) end
  if bit then return bit.bxor(a,b) end
  local r,m=0,1
  while a>0 or b>0 do
    if a%2~=b%2 then r=r+m end
    a=math.floor(a/2)
    b=math.floor(b/2)
    m=m*2
  end
  return r
end
]]

-- ─────────────────────────────────────────────
-- SINGLE ENCODE LAYER
-- Encodes source as XOR byte array, outputs self-decoding Lua
-- ─────────────────────────────────────────────

local function encodeLayer(source)
    local key       = randomKey(32)
    local encrypted = xorBytes(source, key)
    local keyStr    = keyToString(key)
    local dataStr   = bytesToLiteral(encrypted)

    local out = {}
    out[#out+1] = RUNTIME_XOR
    out[#out+1] = "local __K=" .. keyStr
    out[#out+1] = "local __D=" .. dataStr
    out[#out+1] = "local __s={}"
    out[#out+1] = "for __i=1,#__D do __s[__i]=string.char(__xor(__D[__i],__K[((__i-1)%#__K)+1])) end"
    out[#out+1] = "local __fn,__err=(loadstring or load)(table.concat(__s))"
    out[#out+1] = "if not __fn then error(tostring(__err)) end"
    out[#out+1] = "__fn()"

    return table.concat(out, "\n")
end

-- ─────────────────────────────────────────────
-- PUBLIC API
-- ─────────────────────────────────────────────

function obf.obfuscate(source)
    -- Double-layer XOR encoding
    local layer1 = encodeLayer(source)
    local layer2 = encodeLayer(layer1)
    return "-- Obfuscated output\n" .. layer2
end

return obf
