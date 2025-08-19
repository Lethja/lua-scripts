#!/usr/bin/env lua

--[[ Implicit global variables:
	Z = Whether to zero out free clusters or not
]]

-- H = Help string
H = [[This script shows what blocks are allocated to what files on a FAT12/16 formatted floppy disk image (.IMA).
The -z option will shred unallocated clusters. Backup any file before using the -z option on it.]]

if #arg < 1 then -- Print help and exit when there's no arguments
    print(arg[-1] .. " " .. arg[0] .. " [-z] [IMA...]" .. '\n\n' .. H)
    os.exit(1)
end

---Read 16 bits from an offset of a string
---@param s string The string to read from
---@param o number The offset in the string to read at
---@return number The 16-bit value at the offset of the string
function R16(s, o)
    local a, b = s:byte(o, o + 1)
    return a + b * 256
end

---Read 32 bits from an offset of a string
---@param s string The string to read from
---@param o number The offset in the string to read at
---@return number The 32-bit value at the offset of the string
function R32(s, o)
    local a, b, c, d = s:byte(o, o + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

---Read the allocation table of a FAT-12 partition
---@param f file The file the partition is on
---@param o number Offset relative to the file where the FAT partition starts
---@param s number Size of the FAT partition
---@return table A list containing each clusters allocation state
function F12(f, o, s)
    f:seek("set", o)
    local fd, fat, mc = f:read(s), {}, math.floor(s * 8 / 12)

	---Extract the FAT-12 cluster value
	---@param i number Number of the cluster to read
	---@return number The 12-bit cluster number
    function E(i)
        local c = math.floor(i * 1.5)
        local a, b = fd:byte(c + 1) or 0, fd:byte(c + 2) or 0
        if i % 2 == 0 then
            return a + (b & 0x0F) * 256
        else
            return (a >> 4) + b * 16
        end
    end

    for i = 2, mc - 1 do
        fat[i] = E(i)
    end

    return fat
end

---Read the allocation table of a FAT-16 partition
---@param f file The file the partition is on
---@param o number Offset relative to the file where the FAT partition starts
---@param s number Size of the FAT partition
---@return table A list containing each clusters allocation state
function F16(f, o, s)
    f:seek("set", o)
    local fd, fat = f:read(s), {}
    for i = 2, #fd - 1, 2 do
        local lo, hi = fd:byte(i), fd:byte(i + 1)
        fat[((i - 2) // 2) + 2] = lo + hi * 256
    end
    return fat
end

---FAT Determine: Determine if the FAT type (12, 16 or 32) and total cluster count
---@param ts number Total number of sectors on the disk
---@param rs number Reserved sectors before the FAT header
---@param nf number Number of FATs
---@param sf number Sectors per FAT
---@param rd number Root directory sectors
---@param sc number Sectors per cluster
---@return number, number The fat type as a number (12, 16, 32) and the cluster count
function FD(ts, rs, nf, sf, rd, sc)
    local c, r = math.floor((ts - rs - (nf * sf) - rd) / sc)
    r = c < 4085 and 12 or c < 65525 and 16 or 32
    return r, c
end

---Cluster Chain: Parse all clusters that are allocated to a single file
---@param fat table The FAT table
---@param sc number The starting cluster of the file
---@return table List of all applicable clusters
function CC(fat, sc)
    local h, c = {}, sc
    while c >= 2 and c < 0xFF8 do
        table.insert(h, c)
        c = fat[c]
    end
    return h
end

---Format Ranges: Sort and group cluster ranges together for easy reading by humans
---@param c table A list of clusters representing a file allocation
---@return table A list strings representing the same clusters in a sorted and ranged order
function FR(c)
    table.sort(c)
    local ranges, i = {}, 1
    while i <= #c do
        local s, j, f = c[i], i
        while j + 1 <= #c and c[j + 1] == c[j] + 1 do
            j = j + 1
        end
        f = c[j]
        if s == f then
            table.insert(ranges, string.format("<%d>", s))
        else
            table.insert(ranges, string.format("<%d-%d>", s, f))
        end
        i = j + 1
    end
    return table.concat(ranges, " ")
end

---Display Entries: print to the screen what entries belong to what files
---@param f file The file the fat partition is on
---@param o number The offset the directory entries begin at
---@param e number The maximum entries to read
---@param fat table The file allocation table
function DE(f, o, e, fat)
    f:seek("set", o)
    for _ = 1, e do
        local en, fb = f:read(32)
        if not en then
            break
        end
        fb = en:byte(1)
        if fb == 0 then
            break
        end
        if fb ~= 229 and (en:byte(12) & 8) == 0 then
            local n, x = en:sub(1, 8):gsub("+$", ""), en:sub(9, 11):gsub("+$", "")
            io.write(string.format("\t%8s %3s %s\n", n, x, FR(CC(fat, R16(en, 27)))))
        end
    end
end

---Free Clusters: Find and optionally zero out all free clusters
---@param fa table File allocation table
---@param f file File the allocation table is on
---@param st number Starting area of the data area
---@param s number The size of a cluster in bytes
---@param uc number The number of usable clusters
function FC(fa, f, st, s, uc)
    local fr, z = {}, string.rep("\0", s)
    io.write("\n\tFree Space   ")
    for i = 2, uc + 1 do
        if fa[i] == 0 then
            table.insert(fr, i)
            if Z then
                f:seek("set", st + (i - 2) * s)
                f:write(z)
            end
        end
    end
    print(FR(fr))
end

F = {} -- List of files to parse

for _, v in ipairs(arg) do -- Parse all arguments
    if v == "-z" then -- '-z' found, enable zeroing out of unallocated clusters
        Z = 1
    else
        table.insert(F, v)
    end
end

for _, fn in ipairs(F) do -- Iterate over each file
    local f = io.open(fn, (Z and "r+b" or "rb")) -- Read only unless argument '-z' was found
    if f then
        print(fn .. ":")

		-- b = The first 512 bytes of the file
		-- o = The first byte of the file
        local b, o = f:read(512)
        o = b:sub(1, 1):byte()
        if o == 235 or o == 233 then -- The boot sector has a valid jump instruction to a FAT boot sector

			-- bs = Bytes per sector
			-- sc = Sector per cluster
			-- rs = Reserved sectors
			-- nf = Number of FATs
			-- re = Root directory entries
			-- ts = Total sectors
			-- sf = Sectors per FAT
            local bs, sc, rs, nf, re, ts, sf = R16(b, 12), b:byte(14), R16(b, 15), b:byte(17), R16(b, 18), R16(b, 20), R16(b, 23)

			if ts == 0 then -- Use the larger 32-bit number of sectors
                ts = R32(b, 32)
            end

			-- rd = Root directory sectors
			-- fo = FAT offset
			-- fs = FAT size in bytes
			-- ro = Root directory offset
            local rd, fo, fs, ro, ft, uc = math.ceil(re * 32 / bs), rs * bs, sf * bs, (rs + nf * sf) * bs

			-- ft = FAT type
			-- uc = Usable cluster count
            ft, uc = FD(ts, rs, nf, sf, rd, sc)

			-- Print some basic information about the FAT table
            print(string.format("\t       FAT type: FAT%s\n\t   Bytes/sector: %d\n\tSectors/cluster: %d\n\n", ft, bs, sc))

			-- Parse the FAT table
            local fat = ft == 12 and F12(f, fo, fs) or ft == 16 and F16(f, fo, fs) or error("Non-FAT type")

			-- Print state of each cluster
            DE(f, ro, re, fat)
            FC(fat, f, (rs + (nf * sf) + rd) * bs, sc * bs, uc)
        end
        f:close()
        print()
    end
end
