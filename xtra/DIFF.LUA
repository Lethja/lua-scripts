#!/usr/bin/env lua

-- PF = Packaging format for file line data
-- CT = CRC32 lookup table
-- M  = Maximum size of a number (32-bits)
-- S  = Shorthand for "set" (saves 8 bytes)
-- CL = Context lines above and below differences in hunks, controlled by the user with 'DIFF_CONTEXT' environment variable
local PF, CT, M, S, CL = "I2I4I8", {}, 0xFFFFFFFF, "set", tonumber(os.getenv("DIFF_CONTEXT")) or 3

---Print the differences between two files in the unified diff format (the one popular VCS Git uses)
---@param fn1 string Path to the left,old,del etc... file
---@param fn2 string Path to the right,new,add etc... file
local function diff_u(fn1, fn2)

    ---Open and process crc32 checksum of every line in the file
    ---@param fn string The file path to open and parse
    ---@return string A packed array string containing line information
    local function open(fn)
        local f, e = io.open(fn, "rb")
        if not f then
            print(e)
            os.exit(1)
        end

        ---Generate a crc32 checksum from the given string
        ---@param s string The string or data to parse the checksum of
        ---@return number The CRC32 checksum in numeral form
        local function crc32(s)
            local c = M
            for i = 1, #s do
                local byte = s:byte(i)
                c = (c >> 8) ~ CT[(c ~ byte) & 0xFF]
            end
            return (~c) & M
        end

        -- o = current offset
        -- p = packed data
        local o, p = 0, ""

        while 1 do -- Pack the checksum, offset, and length of each line

            -- ls = Line start at file offset
            -- l = Raw characters that make up this line
            local ls, l = o, {}

            while 1 do -- Read byte by byte until a newline character is found
                local c = f:read(1)
                if not c then
                    break
                end

                ---Locate the next end of line segment
                ---It could be any of '\n', '\r' or '\r\n'
                local function eol()
                    if c == '\r' then

                        --[[
                            Determine if this is a
                            classic MacOS end of line ('\r')
                            or a Windows end of line ('\r\n').

                            If it's a Windows end of line continue as one more
                            iteration is where '\n' will be detected.
                        ]]

                        local d = f:read(1) -- Peeking
                        if not d then -- This is the end of the file and '\r' is a newline
                            return true
                        end
                        f:seek("cur", -1) -- Revert from peeking
                        return d ~= '\n'
                    end
                    return c == '\n'
                end

                o = o + 1
                table.insert(l, c)
                if eol() then
                    break
                end
            end
            if #l == 0 then
                break
            end
            l = table.concat(l)
            local ln, c = #l, crc32(l)
            p = p .. string.pack(PF, ln, c, ls)
        end
        f:close()
        return p
    end
    
    -- f1 = file 1 (left, old, del etc...)
    -- f2 = file 2 (right, new, add etc...)
    -- ps = packsize of PF
    -- co = Storage list for finished hunks
    -- i  = The current line number of file 1
    -- j  = The current line number of file 2
    -- la = The previous lines content
    -- fh = Tracks if the file header has been printed yet
    -- h  = The total length (height) of file 1
    -- w  = The total length (width) of file 2
    -- m  = Initially stores individual matches, later holds consolidated hunks
    -- u  = Store the unified diff buffer until it can be printed
    -- L  = A 2D table used for the Longest Common Subsequence (LCS) algorithm
    local f1, f2, ps, co, i, j, la, fh, h, w, m, u, L = open(fn1), open(fn2), string.packsize(PF), {}

    ---Compare a line from file 1 with one from file 2
    ---@param x number The line from file 1 to compare
    ---@param y number The line from file 2 to compare
    ---@return boolean true on match, false otherwise
    local function cmp(x, y)
        
        -- l1 = length of line from file 1
        -- c1 = checksum of line from file 1
        -- o1 = file offset of line from file 1
        -- l2 = length of line from file 2
        -- c2 = checksum of line from file 2
        -- o2 = file offset of line from file 2
        -- b1 = raw binary data from file 1
        -- e  = error string if opening a file causes an error
        -- b2 = raw binary data from file 2
        local l1, c1, o1, l2, c2, o2, b1, e, b2, f = string.unpack(PF, f1, (x - 1) * ps + 1)

        l2, c2, o2 = string.unpack(PF, f2, (y - 1) * ps + 1)

        if l1 ~= l2 or c1 ~= c2 then
            return false -- There's no possible match if length or checksum are different
        end

        ---Read the raw data of a line from a file
        ---@param fn string The file path to open for reading
        ---@param o number The offset to start reading from
        ---@param l number The length to read for
        local function li(fn, o, l)
            f, e = io.open(fn, "rb")
            if not f then
                return nil, e
            end
            f:seek(S, o)
            local g = f:read(l)
            f:close()
            return g
        end

        --[[
            The lines length and checksums have matched.
            As unlikely as it is make sure this isn't a hash collision
            by reading the raw bytes of the line
        ]]

        b1, e = li(fn1, o1, l1)
        if not b1 then
            error(e)
        end

        b2, e = li(fn2, o2, l2)
        if not b2 then
            error(e)
        end

        return b1 == b2
    end

    -- h = The total length (height) of file 1
    -- w = The total length (width) of file 2
    -- m = Stores matching positions in the Longest Common Subsequence (LCS)
    -- u = Store the unified diff buffer until it can be printed
    -- L = A 2D table used for the Longest Common Subsequence (LCS) algorithm
    h, w, la, m, L = #f1 // ps, #f2 // ps, 1, {}, {}

    for x = 0, h do --Longest Common Subsequence (LCS) algorithm
        L[x] = {}
        for y = 0, w do
            if x == 0 or y == 0 then
                L[x][y] = 0
            elseif cmp(x, y) then
                L[x][y] = L[x - 1][y - 1] + 1
            else
                L[x][y] = (L[x - 1][y] > L[x][y - 1]) and L[x - 1][y] or L[x][y - 1]
            end
        end
    end

    -- i = The number of lines to go in file 1
    -- j = The number of lines to go in file 2
    i, j = h, w

    while i > 0 and j > 0 do -- Get subsequence from matrix
        if cmp(i, j) then
            table.insert(m, 1, { x = i, y = j, l = 1 })
            i, j = i - 1, j - 1
        elseif L[i - 1][j] >= L[i][j - 1] then
            i = i - 1
        else
            j = j - 1
        end
    end

    for _, p in ipairs(m) do -- Consolidate matching regions into hunks
        local t = co[#co]
        if t and t.x + t.l == p.x and t.y + t.l == p.y then
            t.l = t.l + 1
        else
            co[#co + 1] = { x = p.x, y = p.y, l = p.l }
        end
    end

    -- m  = The consolidated matches
    -- la = reset the last line for the next loop
    -- i  = reset the number of lines into file 1
    -- j  = Reset the number of lines into file 2
    m, la, i, j = co, nil, 1, 1

    ---Get the raw line from a file
    ---@param fn string The file path to open
    ---@param p string The packed data to read from
    ---@param x number The line to read
    ---@return string The raw line at this position
    local function get(fn, p, x)

        -- l = length of line
        -- _ = skip CRC32
        -- o = offset of line
        -- f = file handle for fn
        -- r = raw data of line
        local l, _, o, f, r = string.unpack(PF, p, (x - 1) * ps + 1)
        f = assert(io.open(fn, "rb"))
        f:seek(S, o)
        r = f:read(l)
        f:close()
        return r
    end

    ---Print Formatted Line
    ---@param p string The string to prepend, usually " ", "+" or "-"
    ---@param s string The line to prepare for printing
    ---@return string The formatted line with any newline character stripped out
    local function pfl(p, s)
        return (p .. s:gsub('\n$', ''):gsub('\r$', ''))
    end

    ---Flush any remaining hunk information
    local function flush()
        if #u.l > 0 then
            if u.e > CL then
                table.remove(u.l)
                u.o.l, u.n.l = u.o.l - 1, u.n.l - 1
            end
            table.insert(u.l, 1, "@@ -" .. u.o.s .. (u.o.l == 1 and "" or "," .. u.o.l) .. " +" .. u.n.s .. (u.n.l == 1 and "" or "," .. u.n.l) .. " @@")
            if not fh then
                local function fn(s)
                    return string.match(s, "%s") and '"' .. s .. '"' or s
                end
                table.insert(u.l, 1, "+++ " .. fn(fn2))
                table.insert(u.l, 1, "--- " .. fn(fn1))
                fh = true
            end
            for _, v in ipairs(u.l) do
                print(v)
            end
        end
        u = nil
    end

    ---Create a new unified diff hunk table if it hasn't been made already
    local function init()
        if not u then
            local k, l = math.max(i - 3, 1), math.max(j - 3, 1)
            u = { e = 0, l = {}, o = { s = k, l = 0 }, n = { s = l, l = 0 } }
            for z = k, i - 1 do
                table.insert(u.l, pfl(" ", get(fn1, f1, z)))
                u.o.l, u.n.l = u.o.l + 1, u.n.l + 1
            end
        end
    end

    for _, p in ipairs(m) do -- Make the unified diff output
        while i < p.x do -- Format all removal lines of this hunk
            init()
            table.insert(u.l, pfl("-", get(fn1, f1, i)))
            i, u.o.l, u.e = i + 1, u.o.l + 1, 0
        end
        while j < p.y do -- Format all addition lines of this hunk
            init()
            table.insert(u.l, pfl("+", get(fn2, f2, j)))
            j, u.n.l, u.e = j + 1, u.n.l + 1, 0
        end
        if u then -- Continue to add content lines after differences
            local c = p.l > CL + 2 and CL + 1 or p.l
            while u.e < c and i <= h and j <= w do
                table.insert(u.l, pfl(" ", get(fn1, f1, i)))
                i, j, u.e, u.o.l, u.n.l = i + 1, j + 1, u.e + 1, u.o.l + 1, u.n.l + 1
            end
            if p.l > 5 then
                flush()
            end
        end
        i, j = p.x + p.l, p.y + p.l
    end

    ---New Line Comment: if the last line didn't end in a new line
    ---then print this comment so the patches line count remains valid
    local function nlc()
        if la then
            la = la:sub(-1)
            if la ~= '\n' and la ~= '\r' then
                table.insert(u.l, "\\ No newline at end of file")
            end
        end
    end

    while i <= h do -- Treat any remaining lines from file 1 as removals
        init()
        la = get(fn1, f1, i, ps)
        table.insert(u.l, pfl("-", la))
        i, u.o.l, u.e = i + 1, u.o.l + 1, 0
    end
    nlc()

    while j <= w do -- Treat any remaining lines from file 2 as additions
        init()
        la = get(fn2, f2, j, ps)
        table.insert(u.l, pfl("+", la))
        j, u.n.l, u.e = j + 1, u.n.l + 1, 0
    end
    nlc()

    if u then
        flush()
    end
end

if #arg < 2 or #arg % 2 ~= 0 then -- There needs to be a even number of arguments (old new old new old new etc...)
    print(arg[-1] .. " " .. arg[0] .. [[ old new...

Compare differences between files, print them as unified context.
To compare multiple files,write them sequentially.
Example: ']] .. arg[0] .. [[ old1 new1 old2 new2 old3 new3' etc...]])
    os.exit(1)
end

for i = 0, 255 do -- Build the CRC32 lookup table
    local c = i
    for _ = 1, 8 do
        c = (c & 1 ~= 0) and (c >> 1) ~ 0xEDB88320 or c >> 1
    end
    CT[i] = c
end

for i = 1, #arg, 2 do
    diff_u(arg[i], arg[i + 1])
end
