if not LIB then print("Please run unzip instead") os.exit(1) end

---Inflate (a.k.a decompress) a deflated file inside a zip
---@param r function The reader function
---@param w function The writer function
---@param z boolean Is this deflate64
function inflate(r, w, z)

	local Z = z and 65536 or 32768

	---New bit stream
	---@param rf function The reader function that returns a string of raw bytes
	---@return table A table full of functions to advance the bitstream (LSB first)
	function nbs(rf)

		-- b = buffer
		-- p = position
		-- bb = bit buffer
		-- bc = bit count
		local b, p, bb, bc = "", 1, 0, 0

		---Ensure at least the requested amount of bits are available in the stream, refilling from the byte stream if needed
		---@param n number The number of bits to have available in the bitstream
		function nb(n)
			while bc < n do
				if p > #b then

					---Fill
					function I()
						if p > #b then
							b = rf()
							if b or #b ~= 0 then p = 1 else return 0 end
						end
						return 1
					end

					if I()==0 then error("!EOF",0) end
				end

				bb = bb + (b:byte(p) << bc)
				p = p + 1
				bc = bc + 8
			end
		end

		---Read a certain number of bits from the bitstream
		---@param n number The amount of bits to read
		---@return number The bits that where read
		function rb(n)
			nb(n)
			local v = bb & ((1 << n) - 1)
			bb, bc = (bb >> n), bc - n
			return v
		end

		---Discard pending bits and align to the next byte boundary
		function ab() bb, bc = 0, 0 end

		-- return.r = read bits
		-- return.a = align to byte
		return { r = rb, a = ab }
	end

	-- bs = bit stream
	-- op = output position
	-- kg = keep going (in a loop)
	-- sw = sliding window (32KB circular buffer)
	-- wp = window pointer
	-- o  = output chunk buffer
	local bs, op, kg, sw, wp, o = nbs(r), 0, 1, {}, 0, {}

	---Flush all unwritten data to the output file
	function F()
		if #o > 0 then
			w(table.concat(o))
			o = {}
		end
	end

	---Append byte
	function ab(byte)
		op = op + 1

		-- Add to output chunk
		o[#o +1] = string.char(byte)
		if #o >= 4096 then F() end

		-- Add to history window
		sw[wp] = byte
		wp = (wp + 1) % Z
	end

	---Make huffman
	function mh(lengths)

		-- m = maximum length
		-- c = counts
		-- d = code
		-- n = next code
		-- t = tab
		local m, c, d, n, t = 0, {}, 0, {}, {}

		for _, len in ipairs(lengths) do
			if len > 0 then
				c[len] = (c[len] or 0) + 1
				if len > m then m = len end
			end
		end

		-- b = bits
		for b = 1, m do
			d = (d + (c[b - 1] or 0)) << 1
			n[b] = d
		end

		---Reverse bits
		function rv(x, bits)
			local y = 0

			for _ = 1, bits do
				y = (y << 1) | (x & 1)
				x = x >> 1
			end

			return y
		end

		-- s = sym
		-- l = len
		for s, l in ipairs(lengths) do
			if l > 0 then
				t[rv(n[l], l)] = { sym = s - 1, len = l }
				n[l] = n[l] + 1
			end
		end

		return { tab = t, max = m }
	end

	---Read huffman
	function rh(h)

		-- c = code
		local c = 0

		-- l = len
		for l = 1, h.max do
			c = c | (bs.r(1) << (l - 1))
			local e = h.tab[c & ((1 << l) - 1)]
			if e and e.len == l then return e.sym end
		end

		error("!Huffman", 0)
	end

	---Append string
	function as(s) for i = 1, #s do ab(s:byte(i)) end end

	while kg > 0 do

		-- f = final
		-- t = block type
		local f, t = bs.r(1), bs.r(2)

		if t == 0 then -- uncompressed block

			-- lo = lower bits of 16-bit value
			-- hi = higher bits of 16-bit value
			--  l = length of value
			local lo, hi, l
			bs.a() -- align (disregard remaining bits)
			lo, hi = bs.r(8), bs.r(8) -- read length
			l = lo + hi * 256 -- calculate length
			lo, hi = bs.r(8), bs.r(8) -- read n-length
			if (l ~ (lo + hi * 256)) ~= 0xFFFF then error("stored block LEN/NLEN mismatch", 0) end
			for _ = 1, l do ab(bs.r(8)) end -- copy raw data

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
				local hl, hd, hc, od, cl, le, ch = bs.r(5) + 257, (z and bs.r(6) or bs.r(5)) + 1, bs.r(4) + 4, {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}, {}, {}

				for i = 1, 19 do cl[i] = 0 end
				for i = 1, hc do cl[od[i] + 1] = bs.r(3) end
				ch = mh(cl)

				while #le < hl + hd do

					-- s = sym
					local s = rh(ch)

					if s <= 15 then
						le[#le + 1] = s
					elseif s == 16 then
						local x, l = bs.r(2) + 3, le[#le]
						for _ = 1, x do le[#le + 1] = l
						end
					elseif s == 17 then
						local x = bs.r(3) + 3
						for _ = 1, x do le[#le + 1] = 0 end
					elseif s == 18 then
						local x = bs.r(7) + 11
						for _ = 1, x do le[#le + 1] = 0 end
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
				{1,0},{2,0},{3,0},{4,0},
				{5,1},{7,1},
				{9,2},{13,2},
				{17,3},{25,3},
				{33,4},{49,4},
				{65,5},{97,5},
				{129,6},{193,6},
				{257,7},{385,7},
				{513,8},{769,8},
				{1025,9},{1537,9},
				{2049,10},{3073,10},
				{4097,11},{6145,11},
				{8193,12},{12289,12},
				{16385,13},{24577,13},

				-- Inflate64 below
				{32769,14},{49153,14},
				{65537,15},{98305,15},
				{131073,16},{196609,16},
				{262145,17},{393217,17},
				{524289,18},{786433,18},
				{1048577,19},{1572865,19},
				{2097153,20},{3145729,20},
				{4194305,21},{6291457,21},
				{8388609,22},{12582913,22},
				{16777217,23},{25165825,23},
				{33554433,24},{50331649,24},
				{67108865,25},{100663297,25},
				{134217729,26},{201326593,26},
				{268435457,27},{402653185,27},
				{536870913,28},{805306369,28},
				{1073741825,29},{1610612737,29},
				{2147483649,30},{3221225473,30},
			}

			-- Strip addition table values out when not in inflate64 mode
			if not z then
				for _ = 1, 33 do
					table.remove(dix)
				end
			end

			while true do
				-- s = sym
				local s = rh(h)
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
					l = b + a
					if d.max > 0 and #d.tab > 0 then
						ds = rh(d)
						de = dix[ds + 1]
						db, dx = de[1], de[2]
						da = dx > 0 and bs.r(dx) or 0
						dv = db + da

						if dv <= 0 or dv > op then
							print("!Distance", dv, Z, op) os.exit(1)
						end

						-- Read from window history
						for _ = 1, l do
							local p = (wp - dv) % Z
							ab(sw[p] or 0)
						end
					end
				end
			end
		else
			error("!Unsupported", 0)
		end

		if f == 1 then kg = 0 end
	end

	F()
end
