#!/usr/bin/env lua

---Get file hash
---@param file file The file to read
---@return string MD5 checksum
function md5_file(file)
    local MAX = 0xFFFFFFFF -- Maximum value of number (32-bits)

    ---MD5 transformation function
    ---@param ch string A 64-byte chunk of the message
    ---@param A number First word of the current hash state
    ---@param B number Second word of the current hash state
    ---@param C number Third word of the current hash state
    ---@param D number Fourth word of the current hash state
    ---@return number, number, number, number Updated hash state (A, B, C, D)
    local function T(ch, A, B, C, D)
        -- F = Conditional function (if x then y else z)
        -- G = Multiplexer function (if z then x else y)
        -- H = Parity function (XOR of all inputs)
        -- I = Nonlinear mixing function
        -- LS = Left bit rotation
        local F, G, H, I, LS = function(x, y, z)
            return (x & y) | (~x & z)
        end, function(x, y, z)
            return (x & z) | (y & ~z)
        end, function(x, y, z)
            return x ~ y ~ z
        end, function(x, y, z)
            return y ~ (x | ~z)
        end, function(x, n)
            return ((x << n) | (x >> (32 - n))) & MAX
        end
        local wo, sh, a, b, c, d = {}, { { 7, 12, 17, 22 }, { 5, 9, 14, 20 }, { 4, 11, 16, 23 }, { 6, 10, 15, 21 } }, A, B, C, D
        for i = 0, 15 do
            local o = i * 4 + 1
            wo[i + 1] = string.byte(ch, o) | (string.byte(ch, o + 1) << 8) | (string.byte(ch, o + 2) << 16) | (string.byte(ch, o + 3) << 24)
        end
        for i = 1, 64 do
            local r, f, g, t = math.floor((i - 1) / 16) + 1
            local s = sh[r][(i - 1) % 4 + 1]
            if r == 1 then
                f = F(b, c, d)
                g = (i - 1) % 16
            elseif r == 2 then
                f = G(b, c, d)
                g = (5 * (i - 1) + 1) % 16
            elseif r == 3 then
                f = H(b, c, d)
                g = (3 * (i - 1) + 5) % 16
            elseif r == 4 then
                f = I(b, c, d)
                g = (7 * (i - 1)) % 16
            end
            t = d
            d = c
            c = b
            b = (b + LS((a + f + wo[g + 1] + SINE[i]) & MAX, s)) & MAX
            a = t
        end

        A = (A + a) & MAX
        B = (B + b) & MAX
        C = (C + c) & MAX
        D = (D + d) & MAX
        return A, B, C, D
    end

    ---Create MD5 padding for message
    ---@param msgLen number The length of the message in bytes
    ---@return string The padding string to append to the message
    local function P(msgLen)
        local ml, p, pl = msgLen * 8, "\128", (56 - (msgLen % 64))
        if pl <= 0 then
            pl = pl + 64
        end
        p = p .. string.rep("\0", pl - 1)
        for i = 0, 7 do
            p = p .. string.char((ml >> (8 * i)) & 0xFF)
        end
        return p
    end

    local A, B, C, D, l = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0
    while 1 do
        local c = file:read(64)
        if not c then
            break
        end
        l = l + #c
        if #c < 64 then
            c = c .. P(l)
        end
        A, B, C, D = T(c, A, B, C, D)
        if #c > 64 then
            break
        end
    end
    local function hex(x)
        return string.format("%02x%02x%02x%02x", x & 0xFF, (x >> 8) & 0xFF, (x >> 16) & 0xFF, (x >> 24) & 0xFF)
    end
    return hex(A) .. hex(B) .. hex(C) .. hex(D)
end

---Initialize the MD5 sine constants table
local function init()
    SINE = {}
    for i = 1, 64 do
        SINE[i] = math.floor(2 ^ 32 * math.abs(math.sin(i)))
    end
end

if LIB then
    init()
    return -- Don't run below code if brought in as a library
end

if #arg < 1 then
    print((arg[-1] or "?") .. " " .. (arg[0] or "?") .. " [FILE]...")
    os.exit(1)
else
    init()
    for i = 1, #arg do
        local f, e = io.open(arg[i], "rb") --#squish keep-eol
        if f then
            local sum = md5_file(f)
            f:close()
            if sum then
                print(sum .. "  " .. arg[i])
            else
                print(arg[i] .. ": " .. "Unknown error")
                os.exit(-1)
            end
        else
            print(e)
            os.exit(1)
        end
    end
end --#squish keep-eol
