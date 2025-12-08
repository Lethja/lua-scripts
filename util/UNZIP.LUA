#!/usr/bin/env lua

local function newbitstream(data)
    local pos, bitbuf, bitcnt = 1, 0, 0
    local function needbits(n)
        while bitcnt < n do
            bitbuf = bitbuf + ((data:byte(pos) or 0) << bitcnt)
            pos = pos + 1
            bitcnt = bitcnt + 8
        end
    end
    local function readbits(n)
        needbits(n)
        local v = bitbuf & ((1 << n) - 1)
        bitbuf, bitcnt = (bitbuf >> n), bitcnt - n
        return v
    end
    local function alignbyte() bitbuf, bitcnt = 0, 0 end
    local function skip(n) pos = pos + n end
    return { readbits = readbits, align = alignbyte, pos = pos, skip = skip }
end

local function revbits(x, bits)
    local y = 0
    for _ = 1, bits do
        y = (y << 1) | (x & 1)
        x = x >> 1
    end
    return y
end

local function make_huff(lengths)

    -- m = maximum length
    -- c = counts
    -- o = code
    -- n = next code
    -- t = tab
    local m, c, o, n, t = 0, {}, 0, {}, {}

    for _, len in ipairs(lengths) do
        if len > 0 then
            c[len] = (c[len] or 0) + 1
            if len > m then m = len end
        end
    end

    -- b = bits
    for b = 1, m do
        o = (o + (c[b - 1] or 0)) << 1
        n[b] = o
    end

    -- s = sym
    -- l = len
    for s, l in ipairs(lengths) do
        if l > 0 then
            local r = revbits(n[l], l)
            t[r] = { sym = s - 1, len = l }
            n[l] = n[l] + 1
        end
    end

    return { tab = t, max = m }
end

local function read_huff(bs, h)

    -- c = code
    local c = 0

    -- l = len
    for l = 1, h.max do
        c = c | (bs.readbits(1) << (l - 1))
        local e = h.tab[c & ((1 << l) - 1)]
        if e and e.len == l then return e.sym end
    end

    error("invalid Huffman code")
end

local function inflate(data)
    local bs, out, outpos = newbitstream(data), {}, 0
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
                local a,b = s:byte(i,i+1) return a + b*256
            end
            local len, _ = le16(data, p), le16(data, p + 2)
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

            local len_extra, dist_extra = {
                [257]={3,0},[258]={4,0},[259]={5,0},[260]={6,0},[261]={7,0},
                [262]={8,0},[263]={9,0},[264]={10,0},[265]={11,1},[266]={13,1},
                [267]={15,1},[268]={17,1},[269]={19,2},[270]={23,2},[271]={27,2},
                [272]={31,2},[273]={35,3},[274]={43,3},[275]={51,3},[276]={59,3},
                [277]={67,4},[278]={83,4},[279]={99,4},[280]={115,4},[281]={131,5},
                [282]={163,5},[283]={195,5},[284]={227,5},[285]={258,0}
            },{
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
                    local length, dsym = base + add, read_huff(bs, dist)
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
                        append_byte(out[base_index + i]:byte())
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
        crc = crc ~ s:byte(i)
        for _ = 1, 8 do
            crc = (crc >> 1) ~ (0xEDB88320 & (-(crc & 1)))
        end
    end
    return crc ~ 0xFFFFFFFF
end

local function le16(s, i) local a,b = s:byte(i,i+1); return a + b*256 end
local function le32(s, i)
    local a,b,c,d = s:byte(i, i+3)
    return a + b * 256 + c * 65536 + d * 16777216
end

local function unzip(path)
    local f = assert(io.open(path, "rb"))
    local data, pos = f:read("*a"), 1 f:close()
    while true do
        if data:sub(pos, pos+3) ~= "PK\3\4" then break end
        -- _ = version needed
        -- _ = flags
        -- cm = cm
        -- cr = Expected crc32 checksum
        -- cs = Compressed size
        -- us = Uncompressed size
        -- nl = Length of file name
        -- el = Extra length in the file name

        local _, _, cm, cr, cs, us, nl, el = le16(data, pos+4), le16(data, pos+6), le16(data, pos+8), le32(data, pos+14), le32(data, pos+18), le32(data, pos+22), le16(data, pos+26), le16(data, pos+28)

        -- fn = The filename
        -- st = The file Start offset
        local fn, st = data:sub(pos+30, pos+29 + nl), pos + 30 + nl + el

        -- cd = A buffer of the files data
        -- os = The output stream
        local cd, os = data:sub(st, st + cs - 1)

        if cm == 0 then
            os = cd
        elseif cm == 8 then
            os = inflate(cd)
        else
            io.stderr:write("Unsupported compression method: "..tostring(cm).."\n")
        end

        if os then
            if #os ~= us then
                io.stderr:write(string.format("Warning: uncompressed size mismatch for %s: expected %d, got %d\n", fn, us, #os))
            end
            local gotcrc = crc32(os)
            if cr ~= gotcrc then
                io.stderr:write(string.format("CRC mismatch for %s: expected %08x, got %08x\n", fn, cr, gotcrc))
            else
                print(string.format("CRC OK: %08x", gotcrc))
            end

            local dir = fn:match("(.+)/")
            if dir then
                if os.execute then
                    -- portable make dir (POSIX/Windows-friendly-ish)
                    os.execute('mkdir -p "'..dir..'"')
                end
            end
            local of = assert(io.open(fn, "wb"))
            of:write(os)
            of:close()
        end

        pos = st + cs
    end
end

if not arg[1] then
    io.stderr:write("Usage: lua unzip_fixed.lua <file.zip>\n")
    os.exit(1)
end
unzip(arg[1])
