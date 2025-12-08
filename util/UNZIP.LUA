

local function bxor(a,b) return a ~ b end
local function band(a,b) return a & b end
local function bor(a,b) return a | b end
local function lshift(a,b) return a << b end
local function rshift(a,b) return a >> b end

local function newbitstream(data)
    local pos, bitbuf, bitcnt = 1, 0, 0
    local function needbits(n)
        while bitcnt < n do
            local b = data:byte(pos) or 0
            pos = pos + 1
            bitbuf = bitbuf + lshift(b, bitcnt)
            bitcnt = bitcnt + 8
        end
    end
    local function readbits(n)
        needbits(n)
        local v = band(bitbuf, (1 << n) - 1)
        bitbuf = rshift(bitbuf, n)
        bitcnt = bitcnt - n
        return v
    end
    local function alignbyte() bitbuf, bitcnt = 0, 0 end
    local function getpos() return pos end
    local function skip(n) pos = pos + n end
    return { readbits = readbits, align = alignbyte, pos = getpos, skip = skip }
end

local function revbits(x, bits)
    local y = 0
    for i = 1, bits do
        y = (y << 1) | (x & 1)
        x = x >> 1
    end
    return y
end

local function make_huff(lengths)
    local maxlen, counts = 0, {}
    for _, len in ipairs(lengths) do
        if len > 0 then
            counts[len] = (counts[len] or 0) + 1
            if len > maxlen then maxlen = len end
        end
    end

    local code = 0
    local next_code = {}
    for bits = 1, maxlen do
        code = (code + (counts[bits - 1] or 0)) << 1
        next_code[bits] = code
    end

    local tab = {}
    for sym, len in ipairs(lengths) do
        if len > 0 then
            local c = revbits(next_code[len], len)
            tab[c] = { sym = sym - 1, len = len }
            next_code[len] = next_code[len] + 1
        end
    end

    return { tab = tab, max = maxlen }
end

local function read_huff(bs, h)
    local code = 0
    for len = 1, h.max do
        code = code | (bs.readbits(1) << (len - 1))
        local masked = band(code, (1 << len) - 1)
        local e = h.tab[masked]
        if e and e.len == len then return e.sym end
    end
    error("invalid Huffman code")
end

local function inflate(data)
    local bs = newbitstream(data)
    local out = {}         -- out[i] = single-character string for byte i (1-based)
    local outpos = 0
    local function append_byte(byte)
        outpos = outpos + 1
        out[outpos] = string.char(byte)
    end
    local function append_str(s)
        -- push each byte as single-character entry
        for i = 1, #s do
            outpos = outpos + 1
            out[outpos] = s:sub(i,i)
        end
    end

    local done = false
    while not done do
        local final = bs.readbits(1)
        local btype = bs.readbits(2)

        if btype == 0 then
            -- uncompressed block: align, then read LEN, NLEN from byte stream
            bs.align()
            local p = bs.pos()
            local function le16(s, i)
                local a,b = s:byte(i,i+1); return a + b*256
            end
            local len = le16(data, p)
            local nlen = le16(data, p + 2)
            bs.skip(4) -- consume LEN and NLEN
            local s = data:sub(bs.pos(), bs.pos() + len - 1)
            append_str(s)
            bs.skip(len)

        elseif btype == 1 or btype == 2 then
            local litlen, dist
            if btype == 1 then
                -- fixed Huffman
                local ll = {}
                for _ = 0, 143 do ll[#ll+1] = 8 end
                for _ = 144, 255 do ll[#ll+1] = 9 end
                for _ = 256, 279 do ll[#ll+1] = 7 end
                for _ = 280, 287 do ll[#ll+1] = 8 end
                litlen = make_huff(ll)
                local dl = {}
                for _ = 0, 31 do dl[#dl+1] = 5 end
                dist = make_huff(dl)
            else
                -- dynamic Huffman
                local hlit = bs.readbits(5) + 257
                local hdist = bs.readbits(5) + 1
                local hclen = bs.readbits(4) + 4
                local order = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
                local clen = {}
                for i = 1, 19 do clen[i] = 0 end
                for i = 1, hclen do clen[order[i] + 1] = bs.readbits(3) end
                local chuff = make_huff(clen)
                local lens = {}
                while #lens < hlit + hdist do
                    local sym = read_huff(bs, chuff)
                    if sym <= 15 then
                        lens[#lens + 1] = sym
                    elseif sym == 16 then
                        local r = bs.readbits(2) + 3
                        local last = lens[#lens]
                        for _ = 1, r do lens[#lens + 1] = last end
                    elseif sym == 17 then
                        local r = bs.readbits(3) + 3
                        for _ = 1, r do lens[#lens + 1] = 0 end
                    elseif sym == 18 then
                        local r = bs.readbits(7) + 11
                        for _ = 1, r do lens[#lens + 1] = 0 end
                    end
                end
                local ll, dl = {}, {}
                for i = 1, hlit do ll[i] = lens[i] end
                for i = hlit + 1, hlit + hdist do dl[i - hlit] = lens[i] end
                litlen = make_huff(ll)
                dist = make_huff(dl)
            end

            local len_extra = {
                [257]={3,0},[258]={4,0},[259]={5,0},[260]={6,0},[261]={7,0},
                [262]={8,0},[263]={9,0},[264]={10,0},[265]={11,1},[266]={13,1},
                [267]={15,1},[268]={17,1},[269]={19,2},[270]={23,2},[271]={27,2},
                [272]={31,2},[273]={35,3},[274]={43,3},[275]={51,3},[276]={59,3},
                [277]={67,4},[278]={83,4},[279]={99,4},[280]={115,4},[281]={131,5},
                [282]={163,5},[283]={195,5},[284]={227,5},[285]={258,0}
            }
            local dist_extra = {
                {1,0},{2,0},{3,0},{4,0},{5,1},{7,1},{9,2},{13,2},{17,3},{25,3},
                {33,4},{49,4},{65,5},{97,5},{129,6},{193,6},{257,7},{385,7},{513,8},
                {769,8},{1025,9},{1537,9},{2049,10},{3073,10},{4097,11},{6145,11},
                {8193,12},{12289,12},{16385,13},{24577,13}
            }

            while true do
                local sym = read_huff(bs, litlen)
                if sym < 256 then
                    append_byte(sym)
                elseif sym == 256 then
                    break
                else
                    local entry = len_extra[sym]
                    local base, extra = entry[1], entry[2]
                    local add = extra > 0 and bs.readbits(extra) or 0
                    local length = base + add
                    local dsym = read_huff(bs, dist)
                    local dentry = dist_extra[dsym + 1]
                    local dbase, dextra = dentry[1], dentry[2]
                    local dadd = dextra > 0 and bs.readbits(dextra) or 0
                    local distval = dbase + dadd

                    if distval <= 0 or distval > outpos then
                        error("invalid distance "..tostring(distval).." (outpos="..tostring(outpos)..")")
                    end

                    local base_index = outpos - distval
                    for i = 1, length do
                        -- copy byte-by-byte (handles overlaps correctly)
                        local bytechar = out[base_index + i]
                        append_byte(bytechar:byte())
                    end
                end
            end
        else
            error("unsupported block type: "..tostring(btype))
        end

        if final == 1 then done = true end
    end

    return table.concat(out)
end

local function crc32(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
        local b = s:byte(i)
        crc = bxor(crc, b)
        for _ = 1, 8 do
            local mask = -(crc & 1)
            crc = bxor(rshift(crc,1), band(0xEDB88320, mask))
        end
    end
    return bxor(crc, 0xFFFFFFFF)
end

local function le16(s, i) local a,b = s:byte(i,i+1); return a + b*256 end
local function le32(s, i)
    local a,b,c,d = s:byte(i, i+3)
    return a + b*256 + c*65536 + d*16777216
end

local function unzip(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a"); f:close()
    local pos = 1
    while true do
        if data:sub(pos, pos+3) ~= "PK\3\4" then break end
        local version_needed = le16(data, pos+4)
        local flags = le16(data, pos+6)
        local cm = le16(data, pos+8)
        local crc_expected = le32(data, pos+14)
        local comp_size = le32(data, pos+18)
        local uncomp_size = le32(data, pos+22)
        local name_len = le16(data, pos+26)
        local extra_len = le16(data, pos+28)
        local filename = data:sub(pos+30, pos+29 + name_len)
        local start = pos + 30 + name_len + extra_len
        local compdata = data:sub(start, start + comp_size - 1)

        local outstr
        if cm == 0 then
            outstr = compdata
        elseif cm == 8 then
            outstr = inflate(compdata)
        else
            io.stderr:write("Unsupported compression method: "..tostring(cm).."\n")
        end

        if outstr then
            if #outstr ~= uncomp_size then
                io.stderr:write(string.format("Warning: uncompressed size mismatch for %s: expected %d, got %d\n", filename, uncomp_size, #outstr))
            end
            local gotcrc = crc32(outstr)
            if crc_expected ~= gotcrc then
                io.stderr:write(string.format("CRC mismatch for %s: expected %08x, got %08x\n", filename, crc_expected, gotcrc))
            else
                print(string.format("CRC OK: %08x", gotcrc))
            end

            local dir = filename:match("(.+)/")
            if dir then
                if os.execute then
                    -- portable make dir (POSIX/Windows-friendly-ish)
                    os.execute('mkdir -p "'..dir..'"')
                end
            end
            local of = assert(io.open(filename, "wb"))
            of:write(outstr)
            of:close()
        end

        pos = start + comp_size
    end
end

if not arg[1] then
    io.stderr:write("Usage: lua unzip_fixed.lua <file.zip>\n")
    os.exit(1)
end
unzip(arg[1])
