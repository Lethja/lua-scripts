#!/usr/bin/env lua

local function patch(p)
	local pf, e = io.open(p)
	local ol, bl, cp, of, bf, hunk = 0, 0
	if not pf then print(e) os.exit(1) end

	local function parseFileName(l)
		local first = l:sub(5,5)
		if first == '"' or first == "'" then
			return l:match(first .. "([^" .. first .. "]+)" .. first, 5)
		else
			local words = {}
			for v in string.gmatch(l, "%S+") do table.insert(words, v) end
			return words[2]
		end
	end

	local function setPatchFile(f)
		local o, b
		local function abort()
			print(e)
			if o then o:close() end
			if b then b:close() end
			return false
		end
		o, e = io.open(f)if not o then return abort end
		b, e = io.open(f..".orig", "w")if not b then return abort end
		for m in o:lines() do b:write(m..'\n') end o:close() b:close()
		o, e = io.open(f, "w") if not o then return abort end
		b, e = io.open(f..".orig") if not b then return abort end
		if of then of:close() end if bf then bf:close() end of = o bf = b
		return true
	end

	local function writeRemainder()
		if of then
			local rest = bf:read("*l")
			while rest do
				of:write(rest .. '\n')
				rest = bf:read("*l")
			end
			of:close()
		end
		bf:close()
	end

	local n=pf:read("*l")
	while n do
		local l=n n=pf:read("*l")
		local ls = l:sub(1, 1)
		if ls == "+" then
			if l:sub(2,4) == "++ " then
				--TODO: Just ignore this line?
			else
				if of then
					local nl = n and n:match("^\\ No newline at end of file")
					of:write(l:sub(2)..(nl and""or'\n')) ol = ol + 1
				end
			end
		elseif ls == '-' then
			if l:sub(2,4) == "-- " then
				local filename = parseFileName(l)
				if bf then writeRemainder() end
				if setPatchFile(filename) then cp = filename print("\n'" .. cp .. "':") end
			else
				local cmp = bf:read("*l") bl = bl + 1
				if cmp ~= l:sub(2) then print("malformed")os.exit(1) end
			end
		elseif ls == ' ' then
			--TODO: context line verification
			local line = l:sub(2)
			if bf then
				local cmp = bf:read("*l") bl = bl + 1
				if cmp == line then
					if of then of:write(line .. '\n') ol = ol + 1 end
				else
					print("malformed")os.exit(1)
				end
			end

		elseif ls == '@' then
			if l:sub(2,3) == "@ " then
				local function parseHunkHeader()
					local function split(i,d)
						local r={}
						for m in (i..d):gmatch("(.-)"..d)do table.insert(r,m)end
						return r
					end
					local words,old,new=split(l," "),{},{}
					if words[2] then old=split(words[2],",")end
					if words[3] then new=split(words[3],",")end
					if old[1] then old[1]=old[1]:sub(2)end
					if new[1] then new[1]=new[1]:sub(2)end
					return {
						old = { start = tonumber(old[1]), lines = tonumber(old[2]) or 1 },
						new = { start = tonumber(new[1]), lines = tonumber(new[2]) or 1 }
					}
				end
				if hunk then if hunk.old.lines~=bl-(hunk.old.start-1)or hunk.new.lines~=ol-(hunk.new.start-1)then print("malformed")os.exit(1)else print("patched")end end
				hunk=parseHunkHeader()if hunk then
					io.write("\t@@ -"..hunk.old.start..","..hunk.old.lines.." +"..hunk.new.start..","..hunk.new.lines.." @@: ")
					local skip=hunk.old.start>0 and(hunk.old.start-1)-bl or 0
					if skip<0 then print("malformed (overlapping hunk)")os.exit(1)end
					for _=1,skip do
						local ctx=bf:read("*l")if not ctx then print("malformed (unexpected EOF in context)")os.exit(1)end
						bl=bl+1 if of then of:write(ctx.."\n")ol=ol+1 end end end end end end
	pf:close()
	if hunk then print("patched") end
	if bf then writeRemainder() end
end

if #arg < 1 then os.exit(1) end
patch(arg[1], arg[2])
