#!/usr/bin/env lua

P,M="patched","malformed"
local function patch(pf)
	local wl,rl,cp,wf,rf,h,e=0,0
	local function PFN(l)local f=l:sub(5,5)
		if f=='"'or f=="'"then return l:match(f.."([^"..f.."]+)"..f,5)
		else f={}for v in string.gmatch(l,"%S+")do table.insert(f,v)end return f[2]end end
	local function SPF(f)rl,wl=0,0 rf,e=io.open(f)wf,e=io.tmpfile()if e then print("\t"..e)rf,wf=nil,nil end return not e end
	local function R()rl=rl+1 return rf:read("*l")end
	local function RW(x)x:seek("set",0)end
	local function W(s)wl=wl+1 return wf:write(s)end
	local function WR()if h then if(h.o.l>0 and h.o.s>0)and(h.o.l~=rl-(h.o.s-1)or h.n.l~=wl-(h.n.s-1))then print(M)os.exit(1)else print(P)end end
		if rf and wf then local r=R()while r do W(r..'\n')r=R()end
			local function B()local n,f,l=cp:match("(.*)%.[^%.]*")..".bak"f=io.open(n,"a+")
				local function C()RW(f)RW(rf)repeat r,l=R(),rf:read("*l")if r~=l then return 1 end until not r or not l end
				if f:seek()~=rf:seek()or C()then RW(rf)f:close()f=assert(io.open(n,"w"))r=R()repeat f:write(r..'\n')r=R()until not r end end
			B()rf:close()rf=assert(io.open(cp,"w"))RW(wf)r=wf:read("*l")repeat rf:write(r.."\n")r=wf:read("*l")until not r wf:close()wf,wl=nil,0 end
		rf:close()rf,rl,h=nil,0,nil end
	local n=pf:read("*l")while n do local l,f=n n=pf:read("*l")f=l:sub(1,1)if f=='+'then
			if l:sub(2,4)~="++ "then W(l:sub(2)..(n and n:match("^\\ No newline at end of file")and""or'\n'))end
		elseif f=='-'then
			if l:sub(2,4)=="-- "then local fn=PFN(l)if rf then WR()end if SPF(fn)then print("\t"..fn..":")cp=fn end
			elseif R()~=l:sub(2)then print(M)os.exit(1)end
		elseif f==' 'then
			if rf then local c,i=R(),l:sub(2)if c==i then if wf then W(i..'\n')end else print(M)os.exit(1)end end
		elseif f=='@'then if l:sub(2,3)=="@ "then
			local function PHH()local function S(i,d)local r={}for m in(i..d):gmatch("(.-)"..d)do table.insert(r,m)end return r end
				local s,o,w=S(l," "),{},{}if s[2]then o=S(s[2],",")end if s[3]then w=S(s[3],",")end
				if o[1]then o[1]=o[1]:sub(2)end if w[1]then w[1]=w[1]:sub(2)end
				return{o={s=tonumber(o[1]),l=tonumber(o[2])or 1},n={s=tonumber(w[1]),l=tonumber(w[2])or 1}}end
			if h then if h.o.l~=rl-(h.o.s-1)or h.n.l~=wl-(h.n.s-1)then print(M)os.exit(1)else print(P)end end
			h=PHH()if h then io.write("\t\t@@ -"..h.o.s..","..h.o.l.." +"..h.n.s..","..h.n.l.." @@: ")local s=h.o.s>0 and(h.o.s-1)-rl or 0 if s<0 then print(M)os.exit(1)end
				for _=1,s do
					local r=R()if not r then print(M)os.exit(1)end
					if wf then W(r.."\n")end end end end end end
	if rf then WR()end end
if #arg<1 then print(arg[-1].." "..arg[0]..[[ diff...

Patch unified difference file(s)]])os.exit(1)end
for _,a in ipairs(arg)do local f,e=io.open(a)if f then print(a..':')patch(f)f:close()else print(e)end end
