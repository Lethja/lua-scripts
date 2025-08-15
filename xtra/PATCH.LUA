#!/usr/bin/env lua

P,M="patched","malformed"
local function patch(pf)
	local wl,rl,cp,wf,rf,h,e=0,0
	local function parseFileName(l)local f=l:sub(5,5)
		if f=='"'or f=="'"then return l:match(f.."([^"..f.."]+)"..f,5)
		else f={}for v in string.gmatch(l,"%S+")do table.insert(f,v)end return f[2]end end
	local function setPatchFile(f) --TODO: write patch to temporary file first
		local r,w local function abort()print(e)if r then r:close()end if w then w:close()end return false end
		r,e=io.open(f)if not r then return abort()end
		w,e=io.open(f..".orig","w")if not w then return abort()end
		for m in r:lines()do w:write(m..'\n')end r:close()w:close()
		w,e=io.open(f,"w")if not r then return abort()end
		r,e=io.open(f..".orig")if not w then return abort()end
		if wf then wf:close()end if rf then rf:close()end wf,wl,rf,rl,h=w,0,r,0,nil return true end
	local function R()rl=rl+1 return rf:read("*l")end
	local function W(s)wl=wl+1 return wf:write(s)end
	local function writeRemainder()if h then if(h.o.l>0 and h.o.s>0)and(h.o.l~=rl-(h.o.s-1)or h.n.l~=wl-(h.n.s-1))then print(M)os.exit(1)else print(P)end end
		if wf then local rest=R()while rest do W(rest..'\n')rest=R()end wf:close()wf,wl=nil,0 end rf:close()rf,rl,h=nil,0,nil end
	local n=pf:read("*l")while n do
		local l,ls=n n=pf:read("*l")ls=l:sub(1,1)
		if ls=='+'then
			if l:sub(2,4)~="++ "then W(l:sub(2)..(n and n:match("^\\ No newline at end of file")and""or'\n'))end
		elseif ls=='-'then
			if l:sub(2,4)=="-- "then local fn=parseFileName(l)if rf then writeRemainder()end if setPatchFile(fn)then cp=fn print("\n'"..cp.."':")end
			elseif R()~=l:sub(2)then print(M)os.exit(1)end
		elseif ls==' 'then
			if rf then local c,i=R(),l:sub(2)if c==i then if wf then W(i..'\n')end else print(M)os.exit(1)end end
		elseif ls=='@'then if l:sub(2,3)=="@ "then
			local function parseHunkHeader()
				local function split(i,d)local r={}for m in(i..d):gmatch("(.-)"..d)do table.insert(r,m)end return r end
				local s,o,w=split(l," "),{},{}if s[2]then o=split(s[2],",")end if s[3]then w=split(s[3],",")end
				if o[1]then o[1]=o[1]:sub(2)end if w[1]then w[1]=w[1]:sub(2)end
				return{o={s=tonumber(o[1]),l=tonumber(o[2])or 1},n={s=tonumber(w[1]),l=tonumber(w[2])or 1}}end
			if h then if h.o.l~=rl-(h.o.s-1)or h.n.l~=wl-(h.n.s-1)then print(M)os.exit(1)else print(P)end end
			h=parseHunkHeader()if h then
				io.write("\t@@ -"..h.o.s..","..h.o.l.." +"..h.n.s..","..h.n.l.." @@: ")
				local s=h.o.s>0 and(h.o.s-1)-rl or 0 if s<0 then print(M)os.exit(1)end
				for _=1,s do
					local ctx=R()if not ctx then print(M)os.exit(1)end
					if wf then W(ctx.."\n")end end end end end end
	if rf then writeRemainder()end end
if #arg<1 then print(arg[-1].." "..arg[0]..[[ diff...

Patch unified difference file(s)]])os.exit(1)end
for _,a in ipairs(arg)do local f,e=io.open(a)if f then patch(f)f:close()else print(e)end end
