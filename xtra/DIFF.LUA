#!/usr/bin/env lua

local PF,CT,M="I2I4I8",{},0xFFFFFFFF
local function diff_u(fn1,fn2)
	local function open(fn)local f,e=io.open(fn, "rb")if not f then print(e)os.exit(1)end
		local function crc32(s)local c=M for i=1,#s do local byte=s:byte(i)c=(c >> 8)~CT[(c~byte)&0xFF]end return(~c)&M end
		local o,p=0,""while 1 do local ls,l=o,{}
			while 1 do local c=f:read(1)if not c then break end
				local function eol()if c=='\r'then local d=f:read(1)if not d then return true end f:seek("cur",-1)return d~='\n'end return c=='\n'end
				o=o+1 table.insert(l,c)if eol()then break end end
			if #l==0 then break end l=table.concat(l)local ln,c=#l,crc32(l)p=p..string.pack(PF,ln,c,ls)end f:close()return p end
	local f1,f2,ps,la,fh=open(fn1),open(fn2),string.packsize(PF)
	local function cmp(x,y)
		local l1,c1,o1,l2,c2,o2=string.unpack(PF,f1,(x-1)*ps+1)l2,c2,o2=string.unpack(PF,f2,(y-1)*ps+1)
		if l1~=l2 or c1~=c2 then return false end
		local function line(fn,o,l)
			local f,e=io.open(fn,"rb")if not f then return nil,e end
			f:seek("set",o)local g=f:read(l)f:close()return g end
		local b1,e,b2=line(fn1,o1,l1)if not b1 then error(e)end b2,e=line(fn2,o2,l2)if not b2 then error(e)end
		return b1==b2 end
	local h,w,m=#f1//ps,#f2//ps,{}for i=1,h do for j=1,w do if cmp(i,j)then table.insert(m,j+(h*(i-1)))end end end
	local function scr(x,y)local i,j=y+h*(x-1),0 for k=1,#m do if m[k]<=i then j=j+1 else return j,m[k]end end return j end
	local x,y,path=h,w,{}while x>0 and y>0 do
		local s=scr(x,y)if scr(x,y-1)==s-1 then table.insert(path,1,{x=x,y=y})x,y=x-1,y-1
		elseif scr(x-1,y-1)==s then x=x-1 else y=y-1 end end
	local function get(fn,p,i)
		local l,_,o=string.unpack(PF,p,(i-1)*ps+1)
		local f=assert(io.open(fn,"rb"))f:seek("set",o)
		local r=f:read(l)f:close()return r end
	local function pfl(p,s)return(p..s:gsub('\n$',''):gsub('\r$',''))end
	local i,j,u=1,1
	local function flush()if #u.l>0 then
		table.insert(u.l,1,"@@ -"..u.o.s..(u.o.l==1 and""or","..u.o.l).." +"..u.n.s..(u.n.l==1 and""or","..u.n.l).. " @@")
		if not fh then
			local function fn(s)return string.match(s,"%s")and '"'..s..'"'or s end
			table.insert(u.l,1,"+++ "..fn(fn2))table.insert(u.l,1,"--- "..fn(fn1))fh=true end
		for _,v in ipairs(u.l) do print(v)end end u=nil end
	local function init()if not u then u={e=0,l={},o={s=i,l=0},n={s=j,l=0}}end end
	for _,p in ipairs(path)do
		while i<p.x do init()table.insert(u.l,pfl("-",get(fn1,f1,i)))i,u.o.l,u.e=i+1,u.o.l+1,0 end
		while j<p.y do init()table.insert(u.l,pfl("+",get(fn2,f2,j)))j,u.n.l,u.e=j+1,u.n.l+1,0 end
		if u then if u.e<3 then table.insert(u.l,pfl(" ",get(fn1,f1,i)))u.e,u.o.l,u.n.l=u.e+1,u.o.l+1,u.n.l+1 else flush()end end i,j=i+1,j+1 end
	local function nlc() if la then la=la:sub(-1)if la~='\n'and la~='\r'then table.insert(u.l,"\\ No newline at end of file")end end end
	while i<=h do init()la=get(fn1,f1,i,ps)table.insert(u.l,pfl("-",la))i,u.o.l,u.e=i+1,u.o.l+1,0 end nlc()
	while j<=w do init()la=get(fn2,f2,j,ps)table.insert(u.l,pfl("+",la))j,u.n.l,u.e=j+1,u.n.l+1,0 end nlc()
	if u then flush()end end
if#arg<2 or#arg%2~=0 then print(arg[-1].." "..arg[0]..[[ old new...

Compare differences between files, print them as unified context.
To compare multiple files,write them sequentially.
Example: ']]..arg[0]..[[ old1 new1 old2 new2 old3 new3' etc...]])os.exit(1)end
for i=0,255 do local c=i for _=1,8 do c=(c&1~=0)and((c>>1)~0xEDB88320)or(c>>1)end CT[i]=c end
for i=1,#arg,2 do diff_u(arg[i],arg[i+1])end
