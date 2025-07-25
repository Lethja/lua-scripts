#!/usr/bin/env lua

H = [[
DOS and UNIX disagree on what a new line should be
DOS says it's a carriage return followed by a line feed (CRLF)
while UNIX says it's just a line feed on its own (LF).
Many tools (Lua included) don't care while others like
`TYPE` in DOS and Notepad in Windows will not work correctly.
Tools like unix2dos/dos2unix convert line endings between the systems,
however, in doing so, the CR in CRLF on the shebang line might be
interpreted literally and prevent execution on UNIX systems.

This script named "DOS friend" will convert every line ending of the files
passed to it with CRLF with the exception of the first line when a shebang
is present. When this occurs, the line will instead write LFCRLF so that
both system families can pleasantly read and run the file.
]]

if #arg < 1 then
	print(arg[-1] .. " " .. arg[0] .. " [FILE]..." .. '\n\n' .. H)
	os.exit(1)
end

CR = string.char(0x0D)
LF = string.char(0x0A)
CRLF = CR .. LF

local function StripCarriage(str)
	return str:gsub("[" .. CR .. LF .. "]", "")
end

local function Shebang(inFile)
	inFile:seek("set", 0)
	local l = inFile:read("*l")
	if l:match("^#!") then
		local o = StripCarriage(l) .. LF .. CRLF
		l = inFile:read("*l")
		if l ~= "" and l ~= CR then -- Only write 2nd line if it's not blank
			o = o .. StripCarriage(l) .. CRLF
		end
		return o
	end
	inFile:seek("set", 0)
	return nil
end

local function TmpFile(m)
	for i = 1, 10000 do
		local t = tostring(os.time() + i):sub(-8)
		local f, e = io.open(t, "r")
		if not f then f, e = io.open(t, m) return f, e, t end
		f:close()
		i = i + 1
	end
end

for j = 1, #arg do
	local i, e = io.open(arg[j])
	if not i then print(arg[j] .. ": " .. e) else
		local o, t
		o, e, t = TmpFile("wb")
		if not o then
			print(t .. ": " .. e)
		else
			local s = Shebang(i)
			if s then o:write(s) end
			while 1 do
				local l = i:read("*l")
				if l then
					o:write(StripCarriage(l) .. CRLF)
				else
					break
				end
			end
			i:close() o:close()

			--[[
				Swap the temporary file and original file around
				so that the original files is being copied to.
				This allows system file permissions to remain unchanged.
			--]]

			i = io.open(t, "rb")
			o = io.open(arg[j], "wb")
			if i and o then
				while 1 do
					local d = i:read(1024)
					if not d then
						break
					end
					o:write(d)
				end
				i:close() o:close()
			end
			os.remove(t)
		end
	end
end
