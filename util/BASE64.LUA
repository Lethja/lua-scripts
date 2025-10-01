#!/usr/bin/env lua

-- b64c = base64 characters
--   dt = decode table
local b64c, dt = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', {}
for i = 1, #b64c do dt[b64c:sub(i,i)] = i - 1 end

---Encode a file into base64
---@param file file The file to turn into base64
---@return string The base64 string
function base64_encode_file(file)

    -- r = result
    -- l = length
    local r, l = {}, 0
    
    while true do

        -- c = chunk of 3 bytes
        local c = file:read(3)
        if not c or #c == 0 then break end
        
        -- Pad chunk to 3 bytes if needed
        -- pa = padded
        -- p  = pad length
        local p = 3 - #c
        for _ = 1, p do
            c = c .. '\0'
        end
        
        -- Convert 3 bytes to 4 base64 characters
        local b1, b2, b3, c1, c2, c3, c4 = c:byte(1, 3)
        local n = (b1 << 16) + (b2 << 8) + b3
        
        c1 = b64c:sub(((n >> 18) & 63) + 1, ((n >> 18) & 63) + 1)
        c2 = b64c:sub(((n >> 12) & 63) + 1, ((n >> 12) & 63) + 1)
        c3 = b64c:sub(((n >> 6) & 63) + 1, ((n >> 6) & 63) + 1)
        c4 = b64c:sub((n & 63) + 1, (n & 63) + 1)
        
        -- Apply padding
        if p == 1 then
            c4 = '='
        elseif p == 2 then
            c3 = '='
            c4 = '='
        end
        
        local en = c1 .. c2 .. c3 .. c4
        table.insert(r, en)
        
        l = l + 4
        if l >= 76 then -- Standard base64 line length
            table.insert(r, '\n')
            l = 0
        end
    end
    
    return table.concat(r)
end

---Decode a file from base64
---@param file file The file containing the base64 string to decode
---@return string The decoded raw data
function base64_decode_file(file)

    -- r = result
    -- b = buffer
    local r, b = {}, ""
    
    -- Read all data and remove whitespace/newlines
    while true do

        -- l = line
        local l = file:read("l")

        if not l then break end
        b = b .. l:gsub("[^" .. b64c .. "=]", "")
    end
    
    -- Process 4 characters at a time
    for i = 1, #b, 4 do

        -- c = chunk of 3 bytes
        --b1 = byte 1
        --b2 = byte 2
        --b3 = byte 3
        --b4 = byte 4
        --c1 = chunk 1
        --c2 = chunk 2
        --c3 = chunk 3
        local c, b1, b2, b3, b4, n, c1, c2, c3 = b:sub(i, i + 3)
        if #c < 4 then break end
        
        b1, b2, b3, b4 = dt[c:sub(1,1)] or 0, dt[c:sub(2,2)] or 0, dt[c:sub(3,3)] or 0, dt[c:sub(4,4)] or 0
        n = (b1 << 18) + (b2 << 12) + (b3 << 6) + b4
        c1, c2, c3 = string.char((n >> 16) & 255), string.char((n >> 8) & 255), string.char(n & 255)
        
        -- Handle padding
        if c:sub(4,4) == '=' then
            if c:sub(3,3) == '=' then
                table.insert(r, c1) -- Only first byte
            else
                table.insert(r, c1 .. c2) -- First two bytes
            end
        else
            table.insert(r, c1 .. c2 .. c3) -- All three bytes
        end
    end
    
    return table.concat(r)
end

if #arg < 1 or #arg > 2 then
    print(arg[0] .. [[ [-e|-d] [file]
    -e: encode (default)
    -d: decode"]])
    os.exit(1)
end

-- em = encode mode
-- fn = file name
--  f = file pointer
local em, fn, f = 1

for _, v in ipairs(arg) do
    if v == "-d" then
        em = nil
    else
        fn = v
    end
end

if fn then
    f, e = io.open(fn, "rb")
    if not f then
        print(e)
        os.exit(1)
    end
else
    f, e = io.stdin
end

if not f then print(e) exit(1) end

if em then
    local encoded = base64_encode_file(f)
    io.write(encoded)
    if not encoded:sub(-1):match('\n') then
        io.write('\n')
    end
else
    io.write(base64_decode_file(f))
end

-- Close file if it was opened
if fn then
    f:close()
end
