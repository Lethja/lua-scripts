#!/usr/bin/env lua

-- P = common string "patched"
-- M = common string "malformed"
P, M = "patched", "malformed"

---Apply patches from the specified unified diff file
---@param pf string Path to unified diff file
local function patch(pf)
	local wl, rl, cp, wf, rf, h, e = 0, 0

	---Get the filename from a header
	---@param l string The line that the file name is in
	---@return string The file name
	local function PFN(l)
		local f = l:sub(5, 5)
		if f == '"' or f == "'" then -- Get filename from within quotation marks
			return l:match(f .. "([^" .. f .. "]+)" .. f, 5)
		else -- Get filename from the second word
			f = {}
			for v in string.gmatch(l, "%S+") do
				table.insert(f, v)
			end
			return f[2]
		end
	end

	---Close the current read and write patch files and reset the state machine
	local function A()
		if rf then
			rf:close()
		end
		if wf then
			wf:close()
		end
		h, rf, wf, wl, rl = nil, nil, nil, 0, 0
	end

	---Start Patch File
	---@param f string Path to the file to patch
	local function SPF(f)
		rl, wl = 0, 0
		rf, e = io.open(f)
		wf, e = io.tmpfile()
		if e then
			print("\t" .. e)
			rf, wf = nil, nil
		end
		return not e
	end

	---Shorthand to read the next line from 'rf'
	local function R()
		rl = rl + 1
		return rf:read("*l")
	end

	---Rewind a file pointer
	---@param x file The file to rewind to the beginning
	local function RW(x)
		x:seek("set", 0)
	end

	---Copy the contents of one file to another
	---@param a file The file to copy from
	---@param b file The file to copy to
	local function CF(a, b)
		local l, t, s = 0, a:seek("end")
		RW(a)
		s = a:read("*l")
		repeat b:write(s .. (l + #s < t and "\n" or ""))
			l = l + #s
			s = a:read("*l") until not s
	end

	---Shorthand to write the next line to wf
	---@param s string The line to write
	local function W(s)
		wl = wl + 1
		return wf:write(s)
	end

	---End Patch File
	local function EPF()
		if h then
			if (h.o.l > 0 and h.o.s > 0) and (h.o.l ~= rl - (h.o.s - 1) or h.n.l ~= wl - (h.n.s - 1)) then
				print(M)
				A()
			else
				print(P)
			end
		end
		if rf and wf then
			local r, f, l = R()

			while r do
				W(r .. '\n')
				r = R()
			end

			local function B()
				local n = cp:match("(.*)%.[^%.]*") .. ".bak"
				f = io.open(n, "a+")
				local function C() -- Check if the backup is the same
					RW(f)
					RW(rf)
					repeat r, l = R(), rf:read("*l")
						if r ~= l then
							return 1
						end
					until not r or not l
				end
				if f:seek() ~= rf:seek() or C() then -- Create a backup of the original file
					f:close()
					f = assert(io.open(n, "w"))
					CF(rf, f)
				end
			end
			B()
			rf:close()
			rf = assert(io.open(cp, "w"))
			CF(wf, rf)
		end
		A()
	end

	-- n = The first line to be later iterated on in the loop
	local n = pf:read("*l")
	while n do -- Parse the diff file

		-- l = The last line (or one currently to read)
		-- f = The first character in 'l'
		local l, f = n
		n = pf:read("*l") -- Get the next line to process
		f = l:sub(1, 1)

		if f == '-' then
			if l:sub(2, 4) == "-- " then -- New file header
				local fn = PFN(l)
				if rf then
					EPF()
				end
				if SPF(fn) then
					print("\t" .. fn .. ":")
					cp = fn
				end
			elseif not rf or not wf or R() ~= l:sub(2) then -- Del line
				print(M)
				A()
			end
		elseif rf and wf then -- Skip over this diff line if reading or writing file are closed due to a malformed hunk
			if f == '+' then
				if l:sub(2, 4) ~= "++ " then -- Add line
					W(l:sub(2) .. (n and n:match("^\\ No newline at end of file") and "" or '\n'))
				end
			elseif f == ' ' then -- Context line
				if rf then
					local c, i = R(), l:sub(2)
					if c == i then
						if wf then
							W(i .. '\n')
						end
					else
						print(M)
						A()
					end
				end
			elseif f == '@' then
				if l:sub(2, 3) == "@ " then -- Hunk header

					---Parse Hunk Header: Turn string into an organized table of hunks expected variables
					---@return table A table with hunk start line, number of line length
					local function PHH()

						---Split string by token into a table list
						---@param i string The string to split
						---@param d string The token to split the string by
						---@return table A list containing every split string or an empty string if no splits occurred
						local function S(i, d)
							local r = {}
							for m in (i .. d):gmatch("(.-)" .. d) do
								table.insert(r, m)
							end
							return r
						end

						-- s = l split by space into a list
						-- o = left,old,del metadata
						-- w = right,new,add metadata
						local s, o, w = S(l, " "), {}, {}

						-- Verify and move metadata
						if s[2] then
							o = S(s[2], ",")
						end
						if s[3] then
							w = S(s[3], ",")
						end
						if o[1] then
							o[1] = o[1]:sub(2)
						end
						if w[1] then
							w[1] = w[1]:sub(2)
						end

						-- o   = old, left del etc... hunk data
						-- n   = new, right add etc... hunk data
						-- ?.s = start line
						-- ?.l = length of line changes
						return {
							o = {
								s = tonumber(o[1]), l = tonumber(o[2]) or 1
							},
							n = {
								s = tonumber(w[1]), l = tonumber(w[2]) or 1
							}
						}
					end

					if h then -- Report on state of previous hunk if there was one
						if h.o.l ~= rl - (h.o.s - 1) or h.n.l ~= wl - (h.n.s - 1) then
							print(M)
							A()
						else
							print(P)
						end
					end

					h = PHH()
					if h then
						io.write("\t\t@@ -" .. h.o.s .. "," .. h.o.l .. " +" .. h.n.s .. "," .. h.n.l .. " @@: ")
						local s = h.o.s > 0 and (h.o.s - 1) - rl or 0

						if s < 0 then
							print(M)
							A()
						end

						for _ = 1, s do
							local r = R()
							if not r then
								print(M)
								A()
							end
							if wf then
								W(r .. "\n")
							end
						end
					end
				end
			end
		end
	end
	if rf then -- Finish parsing what remains of the open file
		EPF()
	end
end

if #arg < 1 then
	print(arg[-1] .. " " .. arg[0] .. [[ diff...

Patch unified difference file(s)]])
	os.exit(1)
end

for _, a in ipairs(arg) do
	local f, e = io.open(a)
	if f then
		print(a .. ':')
		patch(f)
		f:close()
	else
		print(e)
	end
end
