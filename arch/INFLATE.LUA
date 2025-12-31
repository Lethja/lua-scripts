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
				local hl, hd, hc, od, cl, le, ch = bs.r(5) + 257, bs.r(5) + 1, bs.r(4) + 4, {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}, {}, {}

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

			-- lex = length base & extra bits (pairs of bytes)
			-- dix = distance extra bits (1 byte per entry)
			-- dib = distance base (packed 32-bit LE)
			local lex, dix, dib =
			"\003\000\004\000\005\000\006\000\007\000\008\000\009\000\010\000\011\001\013\001\015\001\017\001\019\002\023\002\027\002\031\002\035\003\043\003\051\003\059\003\067\004\083\004\099\004\115\004\131\005\163\005\195\005\227\005\002\000",
			"\000\000\000\000\001\001\002\002\003\003\004\004\005\005\006\006\007\007\008\008\009\009\010\010\011\011\012\012\013\013\014\014\015\015\016\016\017\017\018\018\019\019\020\020\021\021\022\022\023\023\024\024\025\025\026\026\027\027\028\028\029\029\030\030",
			"\001\000\000\000\002\000\000\000\003\000\000\000\004\000\000\000\005\000\000\000\007\000\000\000\009\000\000\000\013\000\000\000\017\000\000\000\025\000\000\000\033\000\000\000\049\000\000\000\065\000\000\000\097\000\000\000\129\000\000\000\193\000\000\000\001\001\000\000\129\001\000\000\001\002\000\000\001\003\000\000\001\004\000\000\001\006\000\000\001\008\000\000\001\012\000\000\001\016\000\000\001\024\000\000\001\032\000\000\001\048\000\000\001\064\000\000\001\096\000\000\001\128\000\000\001\192\000\000\001\000\001\000\001\128\001\000\001\000\002\000\001\128\002\000\001\000\004\000\001\128\004\000\001\000\008\000\001\128\008\000\001\000\016\000\001\128\16\000\001\000\032\000\001\128\032\000\001\000\064\000\001\128\064\000\001\000\128\000\001\128\128\000\001\000\000\001\001\128\000\001\001\000\000\002\001\128\000\002\001\000\000\004\001\128\000\004\001\000\000\008\001\128\000\008\001\000\000\016\001\128\000\016\001\000\000\032\001\128\000\032\001\000\000\064\001\128\000\064\001\000\000\128\001\128\000\128\001\000\000\000\192"

			while true do
				-- s = sym
				local s = rh(h)
				if s < 256 then
					ab(s)
				elseif s == 256 then
					break
				else

					-- b = base
					-- x = extra
					-- a = add
					-- l = length
					local li, b, x, l = (s - 257) * 2 + 1
					b, x = lex:byte(li), lex:byte(li + 1)
					if s == 285 then b = 258 end

					l = b + (x > 0 and bs.r(x) or 0)

					if d.max > 0 and #d.tab > 0 then

						-- ds = distance symbol
						-- db = distance base
						-- dx = distance extra bits
						-- dv = distance value
						local ds, db, dx, dv = rh(d)

						-- Extract 32-bit unsigned little-endian integer (I4) and extra bits byte
						db = string.unpack("<I4", dib, ds * 4 + 1)
						dx = dix:byte(ds + 1)
						dv = db + (dx > 0 and bs.r(dx) or 0)

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
