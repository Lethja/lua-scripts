#!/usr/bin/env lua

local function patch(p)
	local pf, e = io.open(p)
	local ol, bl, cp, of, bf = 0, 0
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

	for l in pf:lines() do
		local ls = l:sub(1, 1)
		if ls == "+" then
			if l:sub(2,4) == "++ " then
				--TODO: New file
				print("New File: '" .. parseFileName(l) .. "'")
			else
				if of then of:write(l:sub(2) .. '\n') ol = ol + 1 end
			end
		elseif ls == '-' then
			if l:sub(2,4) == "-- " then
				local filename = parseFileName(l)
				if setPatchFile(filename) then cp = filename end
			else
				local cmp = bf:read("*l") bl = bl + 1
				if cmp ~= l:sub(2) then 
					print("Malformed Hunk")
				end
			end
		elseif ls == ' ' then
			--TODO: context line verification
			local line = l:sub(2)
			if bf then
				local cmp = bf:read("*l") bl = bl + 1
				if cmp == line then
					if of then of:write(line .. '\n') ol = ol + 1 end
				else
					print("Malformed Hunk")
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
				--TODO: Something useful with this table
				local hunk=parseHunkHeader()print("Hunk Header",hunk.old.start,hunk.old.lines,hunk.new.start,hunk.new.lines)
				--TODO: Jump through file to when hunk starts
			end
		end
	end
	pf:close()
end

if #arg < 1 then os.exit(1) end
patch(arg[1], arg[2])
