#!/usr/bin/env lua

package.path = package.path .. ";?.LUA" --In case of a case sensitive operating system
LIB=1

---Halt and catch fire if E is set
function D() if E then error(E, 0) end end

---Calculates the CRC32 checksum of a string.
---@param s string The input string to process.
---@param c number An initial CRC32 value for incremental calculation if applicable
---@return number The calculated 32-bit CRC32 checksum.
function crc32(s, c)

	-- x = maximum
	-- c = crc number
	local x = 0xFFFFFFFF
	c = (c or 0) ~ x

	for i = 1, #s do
		c = c ~ s:byte(i)
		for _ = 1, 8 do c = (c >> 1) ~ (0xEDB88320 & (-(c & 1))) end
	end

	return c ~ x
end

---Unzips a ZIP archive file, extracting its contents to the local directory.
---Always supports store. Deflate is supported if the 'INFLATE' module can be found.
---@param z string The path to the ZIP file to extract.
---@param d string The path to extract files to.
function unzip(z, d)

	-- C = Read chunk size
	-- v = System path seperator/Version needed
	-- f = File
	local C, v, f = 4096, package.config:sub(1, 1)
	f, E = io.open(z, "rb") D()
	if not d then d = "." end
	if d:sub(-1) ~= v then d = d .. v end

	while true do

		--  s = Signature
		-- fl = Flags
		-- cm = Compression method
		-- cr = Calculated crc32 checksum
		-- cs = Compressed size
		-- us = Uncompressed size
		-- nl = Length of file name
		-- el = Extra length in the file name
		-- di = Directory
		-- of = Output file
		-- re = Remaining bytes
		-- ec = Expected crc32 checksum
		local s, fl, cm, cr, cs, us, nl, el, fn, di, of, re, ec = f:read(30)
		if not s or #s < 30 or not s:find("^PK\3\4") then break end
		v, fl, cm, _, _, ec, cs, us, nl, el = string.unpack("<HHHHHIIIHH", s, 5)

		fn, E = f:read(nl) D() -- read the filename
		if el > 0 then f:seek("cur", el) end

		re = cs

		---Create all required directories in a path up to a file.
		---@param p string The path to a file to create directories for.
		---@return string The created directory.
		local function M(p)

			-- e = path seperator
			-- c = current path
			local e, c, t = package.config:sub(1, 1), "", {}

			p = p:gsub("[\\/]", e) -- Normalize separators to the current OS
			for i in p:gmatch("[^" .. e .. "]+") do table.insert(t, i) end

			-- i = directory
			for i = 1, #t - 1 do
				c = c == "" and t[i] or c .. e .. t[i]
				os.execute('mkdir "' .. c .. '" ' .. (e == "\\" and '>nul 2>nul' or '>/dev/null 2>&1'))
			end
		end

		---Read compressed data in chunks
		local function R()
			if re <= 0 then return nil end

			-- c = chunk
			local c = f:read(math.min(C, re))
			if c then re = re - #c end
			return c
		end

		-- Setup output file
		fn = d .. fn -- Prepend target directory
		M(fn) -- Create directory

		of, E = io.open(fn, "wb") D()
		print("Extracting: " .. fn)

		if of then
			---Write decompressed data and update CRC
			---@param c string The chunk of decompressed data to write to the file
			local function W(c)
				cr = crc32(c, cr)
				of:write(c)
			end

			if cm == 0 then -- uncompressed file
				while re > 0 do
					local c = R()
					if c then W(c) else break end
				end
			elseif (cm == 8 or cm == 9) and pcall(require, "INFLATE") then -- deflated file
				inflate(R, W, cm == 9)
			else
				print("!Unsupported compression method " .. cm)
			end

			of:close()

			if ec ~= cr then print("!CRC") end
		end
	end

	f:close()
end

if arg[-1] then
	if #arg < 1 then
		print((arg[-1] or "?") .. " " .. (arg[0] or "?") .. " file[.zip]")
		os.exit(1)
	end
	unzip(arg[1])
end

-- If arg[-1] == nil then the script was loaded by an interactive interpreter (most likely to swap disks).
