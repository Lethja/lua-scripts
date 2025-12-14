#!/usr/bin/env lua

-- nbs = new bit stream
local function nbs(reader)

	-- b = buffer
	-- p = position
	-- bb = bit buffer
	-- bc = bit count
	local b, p, bb, bc = "", 1, 0, 0

	local function fill()
		if p > #b then
			b = reader()
			if not b or #b == 0 then return false end
			p = 1
		end
		return true
	end

	-- nb = need bits
	local function nb(n)
		while bc < n do
			if p > #b then
				if not fill() then error("Unexpected EOF") end
			end
			bb = bb + (b:byte(p) << bc)
			p = p + 1
			bc = bc + 8
		end
	end

	-- rb = read bits
	local function rb(n)
		nb(n)
		local v = bb & ((1 << n) - 1)
		bb, bc = (bb >> n), bc - n
		return v
	end

	-- ab = align byte
	local function ab() bb, bc = 0, 0 end

	-- raw = read raw bytes
	local function raw(n)
		ab()
		local out, got = {}, 0
		while got < n do
			if p > #b then
				if not fill() then error("Unexpected EOF") end
			end
			local take = math.min(n - got, #b - p + 1)
			out[#out+1] = b:sub(p, p + take - 1)
			p = p + take
			got = got + take
		end
		return table.concat(out)
	end

	return { r = rb, a = ab, raw = raw }
end

-- rv = revbits
local function rv(x, bits)
	local y = 0

	for _ = 1, bits do
		y = (y << 1) | (x & 1)
		x = x >> 1
	end

	return y
end

-- mh = make huff
local function mh(lengths)

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
			local r = rv(n[l], l)
			t[r] = { sym = s - 1, len = l }
			n[l] = n[l] + 1
		end
	end

	return { tab = t, max = m }
end

-- rh = read huff
local function rh(bs, h)

	-- c = code
	local c = 0

	-- l = len
	for l = 1, h.max do
		c = c | (bs.r(1) << (l - 1))
		local e = h.tab[c & ((1 << l) - 1)]
		if e and e.len == l then return e.sym end
	end

	error("invalid Huffman code")
end

local function inflate(reader, writer)

	-- bs = bit stream
	-- op = output position
	-- kg = keep going (in a loop)
	-- win = sliding window (32KB circular buffer)
	-- wp = window pointer
	-- out = output chunk buffer
	local bs, op, kg, win, wp, out = nbs(reader), 0, true, {}, 0, {}

	-- flush = write to sink
	local function flush()
		if #out > 0 then
			writer(table.concat(out))
			out = {}
		end
	end

	-- ab = append byte
	local function ab(byte)
		op = op + 1

		-- Add to output chunk
		out[#out+1] = string.char(byte)
		if #out >= 4096 then flush() end

		-- Add to history window
		win[wp] = byte
		wp = (wp + 1) % 32768
	end

	-- as = append string
	local function as(s) for i = 1, #s do ab(s:byte(i)) end end

	while kg do

		-- f = final
		-- t = block type
		local f, t = bs.r(1), bs.r(2)

		if t == 0 then
			-- uncompressed block: align, then read LEN, NLEN from byte stream
			local h, len, s = bs.raw(4)
			len = h:byte(1) + h:byte(2)*256
			s = bs.raw(len)
			as(s)

		elseif t == 1 or t == 2 then
			local ll, dl, h, d = {}, {}
			if t == 1 then
				-- fixed Huffman
				for _ = 0, 143 do ll[#ll+1] = 8 end
				for _ = 144, 255 do ll[#ll+1] = 9 end
				for _ = 256, 279 do ll[#ll+1] = 7 end
				for _ = 280, 287 do ll[#ll+1] = 8 end
				h = mh(ll)
				for _ = 0, 31 do dl[#dl+1] = 5 end
				d = mh(dl)
			else
				-- dynamic Huffman

				-- hl = hlit
				-- hd = hdist
				-- hc = hclen
				-- od = order
				-- cl = clen
				-- le = lens
				-- ch = chuff
				local hl, hd, hc, od, cl, le, ch = bs.r(5) + 257, bs.r(5) + 1, bs.r(4) + 4, {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}, {}, {}

				for i = 1, 19 do cl[i] = 0 end
				for i = 1, hc do cl[od[i] + 1] = bs.r(3) end
				ch = mh(cl)

				while #le < hl + hd do

					-- s = sym
					local s = rh(bs, ch)

					if s <= 15 then
						le[#le + 1] = s
					elseif s == 16 then
						local r, l = bs.r(2) + 3, le[#le]
						for _ = 1, r do le[#le + 1] = l
						end
					elseif s == 17 then
						local r = bs.r(3) + 3
						for _ = 1, r do le[#le + 1] = 0 end
					elseif s == 18 then
						local r = bs.r(7) + 11
						for _ = 1, r do le[#le + 1] = 0 end
					end
				end
				for i = 1, hl do ll[i] = le[i] end
				for i = hl + 1, hl + hd do dl[i - hl] = le[i] end
				h = mh(ll) d = mh(dl)
			end

			-- lex = length extra
			-- dix = dist extra
			local lex, dix = {
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
				-- s = sym
				local s = rh(bs, h)
				if s < 256 then
					ab(s)
				elseif s == 256 then
					break
				else

					-- e = entry
					-- b = base
					-- x = extra
					-- a = add
					-- l = length
					-- ds = dsym
					-- de = dentry
					-- db = dbase
					-- dx = dextra
					-- da = dadd
					local e, b, x, a, l, ds, de, db, dx, da, dv = lex[s]

					b, x = e[1], e[2]
					a = x > 0 and bs.r(x) or 0
					l, ds = b + a, rh(bs, d)
					de = dix[ds + 1]
					db, dx = de[1], de[2]
					da = dx > 0 and bs.r(dx) or 0
					dv = db + da

					if dv <= 0 or dv > op then
						error("Invalid distance " .. tostring(dv) .. " (outpos=" .. tostring(op) .. ")")
					end

					-- Read from window history
					for _ = 1, l do
						local p = (wp - dv) % 32768
						ab(win[p] or 0)
					end
				end
			end
		else
			error("Unsupported block type: "..tostring(t))
		end

		if f == 1 then kg = false end
	end

	flush()
end

local function crc32(s, c)

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

local function unzip(path)

	-- C = read chunk size
	-- f = file
	local C, f = 4096

	f, E = io.open(path, "rb")
	if E then print(E) os.exit(1) end

	-- R = read bytes
	local function R(n)
		local s, E = f:read(n)
		if E then print(E) os.exit(1) end
		return s
	end

	local function S(n) f:seek("cur", n) end

	local function le16() local a, b = R(2):byte(1, 2) return a + b * 256 end
	local function le32() local a, b, c, d = R(4):byte(1, 4) return a + b * 256 + c * 65536 + d * 16777216 end

	while true do

		-- s  = signature
		-- v  = version needed
		-- fl = flags
		-- cm = method
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
		local s, v, fl, cm, cr, cs, us, nl, el, fn, os, di, of, re, cr = f:read(4)
		if not s or #s < 4 then break end
		if s ~= "PK\3\4" then break end

		v , E = le16() if not v  then break end -- version
		fl, E = le16() if not fl then break end -- flags
		cm, E = le16() if not cm then break end -- method
		S(4) -- skip modification time and date
		cr, E = le32() if not cr then break end -- crc32
		cs, E = le32() if not cs then break end -- compressed size
		us, E = le32() if not us then break end -- uncompressed size
		nl, E = le16() if not nl then break end -- name length
		el, E = le16() if not el then break end -- extra name length

		fn, E = R(nl) if not fn then break end -- filename
		if el > 0 then S(el) end

		print("Extracting: " .. fn)

		re, cr = cs, 0

		-- reader = read compressed data in chunks
		local function reader()
			if re <= 0 then return nil end
			local chunk = f:read(math.min(C, re))
			if chunk then re = re - #chunk end
			return chunk
		end

		-- Setup output file
		di = fn:match("(.+)/")
		if di and os.execute then
			os.execute('mkdir -p "'.. di ..'"')
		end

		of, E = io.open(fn, "wb")
		if not of then
			print(E)
		else
			-- writer = write decompressed data and update CRC
			local function writer(chunk)
				cr = crc32(chunk, cr)
				of:write(chunk)
			end

			if cm == 0 then
				-- no compression
				while re > 0 do
					local chunk = reader()
					if not chunk then break end
					writer(chunk)
				end
			elseif cm == 8 then
				-- deflate
				inflate(reader, writer)
			else
				print("Unsupported compression")
			end

			of:close()

			if cr ~= cr then print("CRC mismatch") end
		end
	end

	f:close()
end

if #arg < 1 then
	print((arg[-1] or "?") .. " " .. (arg[0] or "?") .. " file[.zip]")
	os.exit(1)
end
unzip(arg[1])
