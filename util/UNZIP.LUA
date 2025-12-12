#!/usr/bin/env lua

-- nbs = new bit stream
local function nbs(data)

	-- p = position
	-- bb = bit buffer
	-- bc = bit count
	local p, bb, bc = 1, 0, 0

	-- nb = need bits
	local function nb(n)
		while bc < n do
			bb = bb + ((data:byte(p) or 0) << bc)
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

	-- s = skip
	local function s(n) p = p + n end

	return { r = rb, a = ab, p = p, s = s }
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
		c = c | (bs.r(1) << (l - 1))
		local e = h.tab[c & ((1 << l) - 1)]
		if e and e.len == l then return e.sym end
	end

	error("invalid Huffman code")
end

local function inflate(data)

	-- bs = bit stream
	-- o = output byte stream
	-- op = output position
	-- d = done
	local bs, o, op, d = nbs(data), {}, 0, false

	-- ab = append byte
	local function ab(byte)
		op = op + 1
		o[op] = string.char(byte)
	end

	-- as = append string
	local function as(s)
		-- push each byte as single-character entry
		for i = 1, #s do
			op = op + 1
			o[op] = s:sub(i,i)
		end
	end

	while not d do

		-- f = final
		-- t = block type
		local f, t = bs.r(1), bs.r(2)

		if t == 0 then
			-- uncompressed block: align, then read LEN, NLEN from byte stream
			bs.a()
			local p = bs.p()
			local function le16(s, i)
				local a,b = s:byte(i,i+1) return a + b*256
			end
			local len, _ = le16(data, p), le16(data, p + 2)
			bs.s(4) -- consume LEN and NLEN
			local s = data:sub(bs.p(), bs.p() + len - 1)
			as(s)
			bs.s(len)

		elseif t == 1 or t == 2 then
			local litlen, dist
			if t == 1 then
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
				ch = make_huff(cl)

				while #le < hl + hd do

					-- s = sym
					local s = read_huff(bs, ch)

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
				local ll, dl = {}, {}
				for i = 1, hl do ll[i] = le[i] end
				for i = hl + 1, hl + hd do dl[i - hl] = le[i] end
				litlen = make_huff(ll)
				dist = make_huff(dl)
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
				local s = read_huff(bs, litlen)
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
					l, ds = b + a, read_huff(bs, dist)
					de = dix[ds + 1]
					db, dx = de[1], de[2]
					da = dx > 0 and bs.r(dx) or 0
					dv = db + da

					if dv <= 0 or dv > op then
						error("invalid distance "..tostring(dv).." (outpos="..tostring(op)..")")
					end

					-- bi = base index
					local bi = op - dv
					for i = 1, l do ab(o[bi + i]:byte()) end
				end
			end
		else
			error("unsupported block type: "..tostring(t))
		end

		if f == 1 then d = true end
	end

	return table.concat(o)
end

local function crc32(s)

	-- x = maximum
	-- c = crc number
	local x, c = 0xFFFFFFFF c = x

	for i = 1, #s do
		c = c ~ s:byte(i)
		for _ = 1, 8 do c = (c >> 1) ~ (0xEDB88320 & (-(c & 1))) end
	end

	return c ~ x
end

local function le16(s, i) local a,b = s:byte(i,i+1) return a + b*256 end
local function le32(s, i) local a,b,c,d = s:byte(i, i+3) return a + b * 256 + c * 65536 + d * 16777216 end

local function unzip(path)

	-- f = file
	-- d = data (or error string string if file can't be opened)
	-- p = position
	local f, d, p = io.open(path, "rb")
	if d then print(d) os.exit(1) end
	d, p = f:read("*a"), 1 f:close()

	while true do
		if d:sub(p, p +3) ~= "PK\3\4" then break end

		-- _ = version needed
		-- _ = flags
		-- cm = cm
		-- cr = Expected crc32 checksum
		-- cs = Compressed size
		-- us = Uncompressed size
		-- nl = Length of file name
		-- el = Extra length in the file name
		local _, _, cm, cr, cs, us, nl, el = le16(d, p +4), le16(d, p +6), le16(d, p +8), le32(d, p +14), le32(d, p +18), le32(d, p +22), le16(d, p +26), le16(d, p +28)

		-- fn = The filename
		-- st = The file Start offset
		local fn, st = d:sub(p +30, p +29 + nl), p + 30 + nl + el

		-- cd = A buffer of the files data
		-- os = The output stream
		local cd, os = d:sub(st, st + cs - 1)

		print("Extracting: " .. fn)

		if cm == 0 then
			-- no compression
			os = cd
		elseif cm == 8 then
			-- deflate
			os = inflate(cd)
		else
			-- unsupported compression
			io.stderr:write("Unsupported compression method: "..tostring(cm).."\n")
		end

		if os then
			if #os ~= us then
				io.stderr:write(string.format("Warning: uncompressed size mismatch for %s: expected %d, got %d\n", fn, us, #os))
			end

			-- c = actual crc32
			local c = crc32(os)

			if cr ~= c then
				io.stderr:write(string.format("CRC mismatch for %s: expected %08x, got %08x\n", fn, cr, c))
			end

			-- di = directory
			local di = fn:match("(.+)/")

			if di then
				if os.execute then
					-- portable make dir (POSIX/Windows-friendly-ish)
					os.execute('mkdir -p "'.. di ..'"')
				end
			end
			local of = assert(io.open(fn, "wb"))
			of:write(os)
			of:close()
		end

		p = st + cs
	end
end

if #arg < 1 then
	print((arg[-1] or "?") .. " " .. (arg[0] or "?") .. " file[.zip]")
	os.exit(1)
end
unzip(arg[1])
