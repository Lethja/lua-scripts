#!/usr/bin/env lua

local PF,CT,M,S="I2I4I8",{},0xFFFFFFFF,"set"
local function diff_u(fn1,fn2)
	local function open(fn)local f,e=io.open(fn,"rb")if not f then print(e)os.exit(1)end
		local function crc32(s)local c=M for i=1,#s do local byte=s:byte(i)c=(c >> 8)~CT[(c~byte)&0xFF]end return(~c)&M end
		local o,p=0,""while 1 do local ls,l=o,{}
			while 1 do local c=f:read(1)if not c then break end
				local function eol()if c=='\r'then local d=f:read(1)if not d then return true end f:seek("cur",-1)return d~='\n'end return c=='\n'end
				o=o+1 table.insert(l,c)if eol()then break end end
			if #l==0 then break end l=table.concat(l)local ln,c=#l,crc32(l)p=p..string.pack(PF,ln,c,ls)end f:close()return p end
	local f1,f2,ps,i,j,la,fh,h,w,m,u=open(fn1),open(fn2),string.packsize(PF),1,1
	local function cmp(x,y)
		local l1,c1,o1,l2,c2,o2,b1,e,b2,f=string.unpack(PF,f1,(x-1)*ps+1)l2,c2,o2=string.unpack(PF,f2,(y-1)*ps+1)if l1~=l2 or c1~=c2 then return false end
		local function li(fn,o,l)f,e=io.open(fn,"rb")if not f then return nil,e end f:seek(S,o)local g=f:read(l)f:close()return g end
		b1,e,b2=li(fn1,o1,l1)if not b1 then error(e)end b2,e=li(fn2,o2,l2)if not b2 then error(e)end return b1==b2 end
	h,w,m=#f1//ps,#f2//ps,{}
	for x=1,h do
		local b={}
		for y=1,w do if cmp(x,y)then table.insert(b,y)end end
		if #m>0 and m[#m].x+m[#m].l==x then
			local function inList(v)for k,p in ipairs(b)do if v==p then return k end end end
			if inList(m[#m].y+m[#m].l) then
				m[#m].l=m[#m].l+1
			else
				--TODO: Know where to run the next block
			end
		else
			table.insert(m,{y=b[1],x=x,l=1})
		end
	end
	local function get(fn,p,x)local l,_,o,f,r=string.unpack(PF,p,(x-1)*ps+1)f=assert(io.open(fn,"rb"))f:seek(S,o)r=f:read(l)f:close()return r end
	local function pfl(p,s)return(p..s:gsub('\n$',''):gsub('\r$',''))end
	local function flush()if #u.l>0 then if u.e>=4 then table.remove(u.l)u.o.l,u.n.l=u.o.l-1,u.n.l-1 end
		table.insert(u.l,1,"@@ -"..u.o.s..(u.o.l==1 and""or","..u.o.l).." +"..u.n.s..(u.n.l==1 and""or","..u.n.l).. " @@")
		if not fh then local function fn(s)return string.match(s,"%s")and'"'..s..'"'or s end table.insert(u.l,1,"+++ "..fn(fn2))table.insert(u.l,1,"--- "..fn(fn1))fh=true end
		for _,v in ipairs(u.l)do print(v)end end u=nil end
	local function init()if not u then local k,l=math.max(i-3,1),math.max(j-3,1)u={e=0,l={},o={s=k,l=0},n={s=l,l=0}}
		for z=k,i-1 do table.insert(u.l,pfl(" ",get(fn1,f1,z)))u.o.l,u.n.l=u.o.l+1,u.n.l+1 end end end
	--TODO: Select correct y grid on each compare table
  print("x","y","l")
	for _,p in ipairs(m)do
		-- Temporary debug code
		print(p.x, p.y, p.l)--[[
		while i<p.x do init()table.insert(u.l,pfl("-",get(fn1,f1,i)))i,u.o.l,u.e=i+1,u.o.l+1,0 end
		while j<p.y do init()table.insert(u.l,pfl("+",get(fn2,f2,j)))j,u.n.l,u.e=j+1,u.n.l+1,0 end
		if u then if u.e<4 then table.insert(u.l,pfl(" ",get(fn1,f1,i)))u.e,u.o.l,u.n.l=u.e+1,u.o.l+1,u.n.l+1 else flush()end end i,j=i+1,j+1 end
	--]]end os.exit(1)
	local function nlc()if la then la=la:sub(-1)if la~='\n'and la~='\r'then table.insert(u.l,"\\ No newline at end of file")end end end
	while i<=h do init()la=get(fn1,f1,i,ps)table.insert(u.l,pfl("-",la))i,u.o.l,u.e=i+1,u.o.l+1,0 end nlc()
	while j<=w do init()la=get(fn2,f2,j,ps)table.insert(u.l,pfl("+",la))j,u.n.l,u.e=j+1,u.n.l+1,0 end nlc()
	if u then flush()end end
if#arg<2 or#arg%2~=0 then print(arg[-1].." "..arg[0]..[[ old new...

Compare differences between files, print them as unified context.
To compare multiple files,write them sequentially.
Example: ']]..arg[0]..[[ old1 new1 old2 new2 old3 new3' etc...]])os.exit(1)end
for i=0,255 do local c=i for _=1,8 do c=(c&1~=0)and(c>>1)~0xEDB88320 or c>>1 end CT[i]=c end
for i=1,#arg,2 do diff_u(arg[i],arg[i+1])end
