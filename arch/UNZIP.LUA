#!/usr/bin/env lua

package.path = package.path .. ";?.LUA" --In case of a case sensitive operating system
LIB=1
S=os.getenv("COMSPEC") and "\\" or "/"

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
---@param l table The list of files in the zip to extract
---@param x table The list of files in the zip to not extract
function unzip(z, d, l, x)

	-- C = Read chunk size
	-- f = File
	local C, f = 4096
	f = io.open(z, "rb")
	if not f then f, E = io.open(z .. ".zip", "rb") D() end
	if not d then d = "." end
	if d:sub(-1) ~= S then d = d .. S end

	while true do

		--  s = Signature
		--  v = Version needed
		-- fl = Flags
		-- cm = Compression method
		-- cr = Calculated crc32 checksum
		-- cs = Compressed size
		-- us = Uncompressed size
		-- nl = Length of file name
		-- el = Extra length in the file name
		-- fn = File name
		-- of = Output file
		-- re = Remaining bytes
		-- ec = Expected crc32 checksum
		local s, re, v, fl, cm, cr, cs, us, nl, el, fn, of, ec = f:read(30), "cur"
		if not s or #s < 30 or not s:find("^PK\3\4") then break end
		v, fl, cm, _, _, ec, cs, us, nl, el = string.unpack("<HHHHHI4I4I4HH", s, 5)
		fn, E = f:read(nl) D() -- read the filename
		if el > 0 then f:seek(re, el) end

		---Table has file name string
		---@param t table The table to check for the string
		---@return boolean true if name exists
		function H(t)
			for _, i in ipairs(t) do
				if i == fn then return true end
			end
		end

		-- Check if this file should be included or excluded from extraction
		if (x and H(x)) or (l and not H(l)) then f:seek(re, cs) goto L end

		re = cs

		---Create all required directories in a path up to a file.
		---@param p string The path to a file to create directories for.
		---@return string The created directory.
		local function M(p)

			-- c = current path
			-- t = table of paths
			local c, t = "", {}

			p = p:gsub("[\\/]", S) -- Normalize separators to the current OS
			for i in p:gmatch("[^" .. S .. "]+") do table.insert(t, i) end

			-- i = directory
			for i = 1, #t - 1 do
				c = c == "" and t[i] or c .. S .. t[i]
				os.execute('mkdir "' .. c .. '" ' .. (S == "/" and '>/dev/null 2>&1' or '>nul'))
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

		---Load a Lua Module if it exists
		---@param m string The module name to look for
		---@return boolean true if the module file is found and loaded, nil otherwise
		function LLM(m)

			-- p = Path
			for p in package.path:gmatch("[^;]+") do

				-- n = File name
				-- o = Opened file
				local n, o = p:gsub("%?", m):gsub("[\\/]", S)
				o = io.open(n, "r")
				if o then o:close() return require(m) end
			end
		end

		-- Setup output file
		fn = d .. fn -- Prepend target directory
		M(fn) -- Create directory

		of, E = io.open(fn, "w+b") D()
		print("Extracting: " .. fn)
		fn = nil

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
			elseif (cm == 8 or cm == 9) and LLM("INFLATE") then -- deflated file
				inflate(R, W, of)
			else
				print("!CM" .. cm)
			end

			of:close()

			if ec ~= cr then print("!CRC") end
		end
		::L:: -- Jump to the end of the loop to iterate again
	end

	f:close()
end

if arg[-1] then
	if #arg < 1 then
		print(arg[-1] .. " " .. (arg[0] or "?") .. " file[.zip] [list] [-x xlist] [-d exdir]")
		os.exit(1)
	end

	-- i = Incrementer
	-- z = Zip file path
	-- l = List of zip files to extract
	-- x = List of zip file to skip
	-- d = Directory path to extract files to
	-- k = Start index of find
	-- m = End index of find
	-- f = The flag character found
	local i, z, l, x, d, k, m, f = 2, arg[1], {}

	while i <= #arg do
		k, m = arg[i]:find("^-.*")

		if k then
			f = arg[i]:sub(2,2)
			if m == 2 and f == 'x' then
				x = {}
			elseif f == 'd' then
				if m > 2 then d = arg[i]:sub(3) else d = arg[i + 1] or nil i = i + 1 end
			end
		else
			table.insert(x and x or l, arg[i])
		end

		i = i + 1
	end

	if #l == 0 then l = nil end
	if x and #x == 0 then x = nil end

	unzip(z, d, l, x)
end

-- If arg[-1] == nil then the script was loaded by an interactive interpreter (most likely to swap disks).
