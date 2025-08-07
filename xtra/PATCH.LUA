#!/usr/bin/env lua

M="malformed"
local function patch(p)
	local pf,e=io.open(p)local ol,bl,cp,of,bf,h=0,0
	if not pf then print(e)os.exit(1)end
	local function parseFileName(l)local first=l:sub(5,5)
		if first=='"'or first=="'"then return l:match(first.."([^"..first.."]+)"..first,5)
		else local words={}for v in string.gmatch(l,"%S+")do table.insert(words,v)end return words[2]end end
	local function setPatchFile(f)
		local o,b local function abort()print(e)if o then o:close()end if b then b:close()end return false end
		o,e=io.open(f)if not o then return abort()end
		b,e=io.open(f..".orig","w")if not b then return abort()end
		for m in o:lines()do b:write(m..'\n')end o:close()b:close()
		o,e=io.open(f,"w")if not o then return abort()end
		b,e=io.open(f..".orig")if not b then return abort()end
		if of then of:close()end if bf then bf:close()end of,ol,bf,bl,h=o,0,b,0,nil return true end
	local function writeRemainder()if of then local rest=bf:read("*l")while rest do of:write(rest..'\n')rest=bf:read("*l")end of:close()of,ol=nil,0 end bf:close()bf,bl,h=nil,0,nil end
	local n=pf:read("*l")while n do
		local l,ls=n n=pf:read("*l")ls=l:sub(1,1)
		if ls=='+'then
			if l:sub(2,4)=="++ " then--ignore
			else if of then local nl=n and n:match("^\\ No newline at end of file")of:write(l:sub(2)..(nl and""or'\n'))ol=ol+1 end end
		elseif ls=='-'then
			if l:sub(2,4)=="-- " then local filename=parseFileName(l)if bf then writeRemainder()end
				if setPatchFile(filename)then cp=filename print("\n'"..cp.."':")end
			else local cmp=bf:read("*l")bl=bl+1 if cmp~=l:sub(2)then print(M)os.exit(1)end end
		elseif ls==' 'then
			if bf then local cmp,line=bf:read("*l"),l:sub(2)bl=bl+1 if cmp==line then if of then of:write(line..'\n')ol=ol+1 end else print(M)os.exit(1)end end
		elseif ls=='@'then if l:sub(2,3)=="@ " then
			local function parseHunkHeader()
				local function split(i,d)local r={}for m in (i..d):gmatch("(.-)"..d)do table.insert(r,m)end return r end
				local words,o,n=split(l," "),{},{}
				if words[2]then o=split(words[2],",")end if words[3]then n=split(words[3],",")end
				if o[1]then o[1]=o[1]:sub(2)end if n[1]then n[1]=n[1]:sub(2)end
				return{o={s=tonumber(o[1]),l=tonumber(o[2])or 1},n={s=tonumber(n[1]),l=tonumber(n[2])or 1}}end
			if h then if h.o.l~=bl-(h.o.s-1)or h.n.l~=ol-(h.n.s-1)then print(M)os.exit(1)else print("patched")end end
			h=parseHunkHeader()if h then
				io.write("\t@@ -"..h.o.s..","..h.o.l.." +"..h.n.s..","..h.n.l.." @@: ")
				local s=h.o.s>0 and(h.o.s-1)-bl or 0 if s<0 then print(M)os.exit(1)end
				for _=1,s do
					local ctx=bf:read("*l")if not ctx then print(M)os.exit(1)end
					bl=bl+1 if of then of:write(ctx.."\n")ol=ol+1 end end end end end end
	pf:close()if h then print("patched")end if bf then writeRemainder()end end
if #arg<1 then print(arg[-1].." "..arg[0]..[[ diff...

Patch a unified difference file]])os.exit(1)end patch(arg[1])
