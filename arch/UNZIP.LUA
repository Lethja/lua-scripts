#!/usr/bin/env lua

package.path = package.path .. ";?.LUA" --In case of a case sensitive operating system
LIB=1

---Halt and catch fire if E is set
function D() if E then error(E, 0) end end

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

function unzip(p)

	-- C = read chunk size
	-- f = file
	local C, f = 4096

	f, E = io.open(p, "rb") D()

	-- R = read bytes
	local function R(n)
		local s, E = f:read(n) D()
		return s
	end

	local function S(n) f:seek("cur", n) end

	---Read the next 2 bytes in the file as a 16-bit little endian number
	local function R16() local a, b = R(2):byte(1, 2) return a + b * 256 end

	---Read the next 4 bytes in the file as a 32-bit little endian number
	local function R32() local a, b, c, d = R(4):byte(1, 4) return a + b * 256 + c * 65536 + d * 16777216 end

	while true do

		-- s  = signature
		-- v  = version needed
		-- fl = flags
		-- cm = Compression method
		-- cr = Expected crc32 checksum
		-- cs = Compressed size
		-- us = Uncompressed size
		-- nl = Length of file name
		-- el = Extra length in the file name
		-- os = The output stream
		-- di = directory
		-- of = output file
		-- re = remaining bytes
		-- cr = crc32 checksum
		local s, v, fl, cm, cr, cs, us, nl, el, fn, os, di, of, re = f:read(4)
		if not s or #s < 4 then break end
		if s ~= "PK\3\4" then break end

		v , E = R16() D() -- version
		fl, E = R16() D() -- flags
		cm, E = R16() D() -- method
		S(4) -- skip modification time and date
		cr, E = R32() D() -- crc32
		cs, E = R32() D() -- compressed size
		us, E = R32() D() -- uncompressed size
		nl, E = R16() D() -- name length
		el, E = R16() D() -- extra name length

		fn, E = R(nl) D() -- filename
		if el > 0 then S(el) end

		print("Extracting: " .. fn)

		re, cr = cs, 0

		---Read compressed data in chunks
		local function RC()
			if re <= 0 then return nil end

			-- c = chunk
			local c = f:read(math.min(C, re))
			if c then re = re - #c end
			return c
		end

		-- Setup output file
		di = fn:match("(.+)/")
		if di and os.execute then
			os.execute('mkdir -p "'.. di ..'"')
		end

		of, E = io.open(fn, "wb") D()

		if of then
			---Write decompressed data and update CRC
			---@param c string The chunk of decompressed data to write to the file
			local function W(c)
				cr = crc32(c, cr)
				of:write(c)
			end

			if cm == 0 then -- uncompressed file
				while re > 0 do
					local c = RC()
					if c then W(c) else break end
				end
			elseif (cm == 8 or cm == 9) and pcall(require, "INFLATE") then -- deflated file
				inflate(RC, W, cm == 9)
			else
				print("!Unsupported compression method " .. cm)
			end

			of:close()

			if cr ~= cr then print("!CRC") end
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
else
	-- The script was loaded by an interactive intepreter (most likely to swap disks).
	if not pcall(require, "INFLATE") then print("No inflate support") end
	print("Insert disk with zipfile and type unzip('zipfile') to begin...")
end
