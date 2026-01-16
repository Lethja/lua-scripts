if not LIB then print("Please run unzip instead") os.exit(1) end

---Inflate (a.k.a decompress) a deflated file inside a zip
---@param r function The reader function
---@param w function The writer function
---@param f file The output file handle to allow seeking the sliding window
function inflate(r, w, f)

	--   b = Buffer
	--   p = Position
	--  bb = Bit buffer
	--  bc = Bit count
	--  op = Output position
	--  kg = Keep going (in a loop)
	-- lex = Length base & extra bits (pairs of bytes)
	-- dix = Distance extra bits (1 byte per entry)
	-- dib = Distance base (packed 32-bit LE)
	local b, p, bb, bc, op, kg, lex, dix, dib = "", 1, 0, 0, 0, 1,

	-- lex, dix & dib are packed string constants
	"\3\0\4\0\5\0\6\0\7\0\8\0\9\0\10\0\11\1\13\1\15\1\17\1\19\2\23\2\27\2\31\2\35\3\43\3\51\3\59\3\67\4\83\4\99\4\115\4\131\5\163\5\195\5\227\5\2\0",
	"\0\0\0\0\1\1\2\2\3\3\4\4\5\5\6\6\7\7\8\8\9\9\10\10\11\11\12\12\13\13\14\14\15\15\16\16\17\17\18\18\19\19\20\20\21\21\22\22\23\23\24\24\25\25\26\26\27\27\28\28\29\29\30\30",
	"\1\0\0\0\2\0\0\0\3\0\0\0\4\0\0\0\5\0\0\0\7\0\0\0\9\0\0\0\13\0\0\0\17\0\0\0\25\0\0\0\33\0\0\0\49\0\0\0\65\0\0\0\97\0\0\0\129\0\0\0\193\0\0\0\1\1\0\0\129\1\0\0\1\2\0\0\1\3\0\0\1\4\0\0\1\6\0\0\1\8\0\0\1\12\0\0\1\16\0\0\1\24\0\0\1\32\0\0\1\48\0\0\1\64\0\0\1\96\0\0\1\128\0\0\1\192\0\0\1\0\1\0\1\128\1\0\1\0\2\0\1\128\2\0\1\0\4\0\1\128\4\0\1\0\8\0\1\128\8\0\1\0\16\0\1\128\16\0\1\0\32\0\1\128\32\0\1\0\64\0\1\128\64\0\1\0\128\0\1\128\128\0\1\0\0\1\1\128\0\1\1\0\0\2\1\128\0\2\1\0\0\4\1\128\0\4\1\0\0\8\1\128\0\8\1\0\0\16\1\128\0\16\1\0\0\32\1\128\0\32\1\0\0\64\1\128\0\64\1\0\0\128\1\128\0\128\1\0\0\0\192"

	---Internal buffer refill function.
	---@return number Zero on error, otherwise the buffer has been filled.
	function fi()
		if p > #b then
			b = r()
			if b and #b ~= 0 then p = 1 else return 0 end
		end
		return 1
	end

	---Ensures at least the requested amount of bits are available in the bitstream, refilling from the reader if needed.
	---@param n number The number of bits required.
	function nb(n)
		while bc < n do
			if p > #b then
				if fi() == 0 then error("!EOF",0) end
			end

			bb = bb + (b:byte(p) << bc)
			p = p + 1
			bc = bc + 8
		end
	end

	---Reads a specific number of bits from the bitstream.
	---@param n number The number of bits to read.
	---@return number The decoded bit value.
	function rb(n)
		nb(n)

		-- v = Extracted bit value
		local v = bb & ((1 << n) - 1)

		bb, bc = (bb >> n), bc - n
		return v
	end

	---Constructs a canonical Huffman decoding table from a list of code lengths.
	---@param ls table An array where the index is the symbol and the value is its bit length.
	---@return table A Huffman object containing the lookup table (`tab`) and the maximum code length (`max`).
	function mh(ls)

		-- m = Maximum length
		-- c = Counts
		-- d = Code
		-- n = Next code
		-- t = Tab
		local m, c, d, n, t = 0, {}, 0, {}, {}

		-- l = Length
		for _, l in ipairs(ls) do
			if l > 0 then
				c[l] = (c[l] or 0) + 1
				if l > m then m = l
				end
			end
		end

		-- i = Bits
		for i = 1, m do
			d = (d + (c[i - 1] or 0)) << 1
			n[i] = d
		end

		---Reverses the order of the lower `bi` bits in an integer.
		---@param x number The integer value containing the bits to reverse.
		---@param bi number The number of bits to process.
		---@return number The bit-reversed value.
		function rv(x, bi)
			local y = 0

			for _ = 1, bi do
				y = (y << 1) | (x & 1)
				x = x >> 1
			end

			return y
		end

		-- s = Sym
		-- l = Len
		for s, l in ipairs(ls) do
			if l > 0 then
				t[rv(n[l], l)] = { sym = s - 1, len = l }
				n[l] = n[l] + 1
			end
		end

		return { tab = t, max = m }
	end

	---Decodes the next symbol from the bitstream using the provided Huffman table.
	---@param h table The Huffman table object containing the lookup table (`tab`) and maximum bit length (`max`).
	---@return number The decoded symbol value.
	function rh(h)

		-- c = Code
		local c = 0

		-- l = Len
		for l = 1, h.max do
			c = c | (rb(1) << (l - 1))

			-- e = Entry
			local e = h.tab[c & ((1 << l) - 1)]

			if e and e.len == l then return e.sym end
		end

		error("!Huffman", 0)
	end

	while kg > 0 do

		-- a = Final
		-- t = Block type
		local a, t = rb(1), rb(2)

		if t == 0 then -- Uncompressed block

			-- lo = Lower bits of 16-bit value
			-- hi = Higher bits of 16-bit value
			--  l = Length of value
			local lo, hi, l

			bb, bc = 0, 0 -- Align and disregard remaining bits
			lo, hi = rb(8), rb(8) -- Read length
			l = lo + hi * 256 -- Calculate length
			lo, hi = rb(8), rb(8) -- Read n-length
			if (l ~ (lo + hi * 256)) ~= 0xFFFF then error("stored block LEN/NLEN mismatch", 0) end

			-- Copy raw data
			while l > 0 do
				if p > #b then if fi() == 0 then error("!EOF", 0) end end

				-- k = Take amount
				-- c = Chunk taken
				local k, c = math.min(l, #b - p + 1)

				c = b:sub(p, p + k - 1)
				w(c)
				op = op + k
				p = p + k
				l = l - k
			end

		elseif t == 1 or t == 2 then

			-- ll = Literal/length bit-lengths
			-- dl = Distance bit-lengths
			--  h = Literal/length Huffman decoding table
			--  d = Distance Huffman decoding table
			local ll, dl, h, d = {}, {}

			if t == 1 then
				-- Fixed Huffman
				for _ = 0, 143 do ll[#ll + 1] = 8 end
				for _ = 144, 255 do ll[#ll + 1] = 9 end
				for _ = 256, 279 do ll[#ll + 1] = 7 end
				for _ = 280, 287 do ll[#ll + 1] = 8 end
				h = mh(ll)
				for _ = 0, 31 do dl[#dl + 1] = 5 end
				d = mh(dl)
			else
				-- Dynamic Huffman

				-- hl = Literal/length code count (HLIT)
				-- hd = Distance code count (HDIST)
				-- hc = Meta-code length count (HCLEN)
				-- od = Permutation order for code lengths
				-- cl = Code lengths for the meta-table
				-- le = Decoded bit-lengths for literal/distance tables
				-- ch = Huffman table for decoding bit-lengths
				local hl, hd, hc, od, cl, le, ch = rb(5) + 257, rb(5) + 1, rb(4) + 4, "\16\17\18\0\8\7\9\6\10\5\11\4\12\3\13\2\14\1\15", {}, {}

				for i = 1, 19 do cl[i] = 0 end
				for i = 1, hc do cl[od:byte(i) + 1] = rb(3) end
				ch = mh(cl)

				while #le < hl + hd do

					-- s = Symbol
					-- x = Repeat count
					-- l = Code length
					local s, x, l = rh(ch)

					if s <= 15 then
						le[#le + 1] = s
					elseif s == 16 then
						x, l = rb(2) + 3, le[#le]
						for _ = 1, x do le[#le + 1] = l end
					elseif s == 17 then
						x = rb(3) + 3
						for _ = 1, x do le[#le + 1] = 0 end
					elseif s == 18 then
						x = rb(7) + 11
						for _ = 1, x do le[#le + 1] = 0 end
					end
				end
				for i = 1, hl do ll[i] = le[i] end
				for i = hl + 1, hl + hd do dl[i - hl] = le[i] end
				h = mh(ll) d = mh(dl)
			end

			while true do

				-- s = Symbol
				local s = rh(h)

				if s < 256 then
					op = op + 1
					w(string.char(s))
				elseif s == 256 then
					break
				else

					-- li = Length index
					-- ba = Base
					--  x = Extra
					--  a = Add
					--  l = Length
					local li, ba, x, l = (s - 257) * 2 + 1

					ba, x = lex:byte(li), lex:byte(li + 1)
					if s == 285 then ba = 258 end
					l = ba + (x > 0 and rb(x) or 0)

					if d.max > 0 and #d.tab > 0 then

						-- ds = Distance symbol
						-- db = Distance base
						-- dx = Distance extra bits
						-- dv = Distance value
						local ds, db, dx, dv = rh(d)

						-- Extract 32-bit unsigned little-endian integer (I4) and extra bits byte
						db = string.unpack("<I4", dib, ds * 4 + 1)
						dx = dix:byte(ds + 1)
						dv = db + (dx > 0 and rb(dx) or 0)

						if dv <= 0 or dv > op then
							print("!Distance", dv, op) os.exit(1)
						end

						-- Read from output history using the file-backed sliding window
						f:seek("end", -dv)

						-- n = Pattern
						local n = f:read(math.min(dv, l))

						n = n:rep(l // dv) .. n:sub(1, l % dv)
						f:seek("end")
						w(n)
						op = op + l
					end
				end
			end
		else
			error("!Unsupported", 0)
		end

		if a == 1 then kg = 0 end
	end
end
