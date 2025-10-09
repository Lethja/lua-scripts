#!/usr/bin/env lua

--[[ Implicit global variables:
	F = Current file handle
	J = Virtual Address of the current resource section
	K = Raw Data Pointer (file offset) of the current resource section
]]

-- I = Format string for 32-bit integers
-- X = Bitmask for directory entry flag
-- V = Windows 95 release date timestamp (August 24, 1995)
-- H = Help string
I, X, V, H = "<I4", 0x80000000, 809222400, [[This script edits timestamps in a PE formatted EXE to the Windows 95 release date.
This allows repeatable builds to be verified by checksum tools. Backup any file before using this tool on it.]]

---Move the file pointer forward by x bytes from current position
---@param x number Number of bytes to move forward
---@return number New position in the file
function C(x)
	return F:seek("cur", x)
end

---Set the file pointer to an absolute position x
---@param x number Position to set the file pointer to
---@return number New position in the file
function S(x)
	return F:seek("set", x)
end

---Read and unpack a value of length l from the current file position
---@param l number Length of the value to read (2 or 4 bytes)
---@return number The unpacked value
function R(l)
	local b = F:read(l)
	if b and #b >= l then
		return string.unpack(l == 2 and "<I2" or I, b)
	end
	error("!EOF")
end

---Write a 32-bit value at a specific position in the file
---@param p number Position to write the value
---@param v number Value to write
function W(p, v)
	S(p)
	F:write(string.pack(I, v))
end

---Parse the MZ header and locate the PE header offset
---@return number Offset to the PE header
function P()
	local mz = F:read(2)
	S(60)
	if mz == "MZ" then
		return R(4)
	end
	error("!MZ")
end

---Find the resource section in the PE file
---@return nil
function O()
	S(J)

	-- s = PE signature, later the size of the optional header
	-- n = Number of sections
	-- h = Magic number position
	-- m = Magic number value
	local s, n, h, m = F:read(4)

	if s ~= "PE\0\0" then
		error("!PE")
	end

	C(2)
	n = R(2) -- Number of sections
	C(12)
	s = R(2) -- Size of optional header
	C(2)
	h, m = C(), R(2) -- Magic number position and value

	if m ~= 267 and m ~= 523 then -- Not a valid PE magic number
		error("!MN")
	end

	S(h + s)

	for _ = 1, n do -- Find the .rsrc section of the executable file

		-- u = Current position
		-- o = 8-byte name field
		local u, o = C(), F:read(8):gsub("\0.*", "")

		C(4)
		J = R(4) -- The virtual address of the current resource section
		C(4)
		K = R(4) -- Raw file offset of this resource section data
		S(u + 40)

		if o == ".rsrc" then -- Found .rsrc section
			return
		end
	end
	error("!rsrc") -- Resource section not found
end

---Modify the version timestamp in binary resource data
---@param p number Virtual address of the resource
---@param s number Size of the resource
function B(p, s)
	S((p - J) + K)

	-- d = Raw resource data
	-- t = UTF-16LE string to search for
	-- k = position of version info if found
	local d, t, k = F:read(s), ("VS_VERSION_INFO"):gsub(".", "\0%1") .. "\0\0"

	k = d:find(t, 1, 1)
	if k then -- Set file timestamp on VS_VERSION_INFO
		k = k + #t + ((4 - ((k + #t) % 4)) % 4) + 44
		d, t = C() + (k - s)
		W(d, 0)
		W(d + 4, V)
	end
end

---Traverse the resource directory structure recursively
---@param o number Offset in the resource section
---@param l number Current directory level
---@param v boolean Whether to modify timestamps
function A(o, l, v)

	-- d = position of timestamp field in current resource directory
	-- n = number of named entities
	-- t = total entity count
	-- e = entry start offset
	local d, n, i, t, e = K + o + 4

	W(d, V) -- Set timestamp to Windows 95 date
	C(4)
	n, i = R(2), R(2) -- Named entries count, ID entries count
	t, e = n + i, d + 12
	for j = 0, t - 1 do -- Iterate over the resource directory
		S(e + (j * 8))
		i, d = R(4), R(4) -- ID/Name, offset to data or subdirectory
		if (d & X) ~= 0 then
			A(d & (X - 1), l + 1, v or (l == 1 and i == 16)) -- Process subdirectory
		elseif v and l == 3 then -- Process VS_VERSION_INFO resource
			local r = C()
			S(K + d)
			B(R(4), R(4))
			S(r)
		end
	end
end

if #arg < 1 then -- Show help and exit if no arguments have been given
	print(arg[0], "'[PE...]'\n\n" .. H)
	os.exit(1)
end

for _, v in ipairs(arg) do
	io.write(v .. ": ")
	F = assert(io.open(v, "r+b"))
	J = P() -- Find PE header offset
	W(J + 8, V) -- Update PE header timestamp
	O() -- Find resource section
	A(0, 1) -- Process resource directory
	F:close()
	print("OK")
end
