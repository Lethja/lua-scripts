#!/usr/bin/env lua

local PF,CT,M="I2I4I8",{},0xFFFFFFFF
local function diff_u(fn1,fn2)
	local function open(fn)local f,e=io.open(fn, "rb")if not f then print(e)os.exit(1)end
		local function crc32(s)local c=M for i=1,#s do local byte=s:byte(i)c=(c >> 8)~CT[(c~byte)&0xFF]end return(~c)&M end
		local o,p=0,""while 1 do local ls,l=o,{}
			while 1 do local c=f:read(1)if not c then break end
				local function eol()if c=='\r'then local d=f:read(1)f:seek("cur",-1)return d~='\n'end return c=='\n'end
				o=o+1 table.insert(l,c)if eol()then break end end
			if #l==0 then break end l=table.concat(l)local ln,c=#l,crc32(l)p=p..string.pack(PF,ln,c,ls)end f:close()return p end
	local f1,f2,size=open(fn1),open(fn2),string.packsize(PF)
	local function cmp(x,y)
		local l1,c1,o1=string.unpack(PF,f1,(x-1)*size+1)
		local l2,c2,o2=string.unpack(PF,f2,(y-1)*size+1)
		if l1~=l2 or c1~=c2 then return false end
		local function bin()
			local function line(fn,o,l)
				local f,e=io.open(fn,"rb")if not f then return nil,e end
				f:seek("set",o)local get=f:read(l)f:close()return get end
			local b1,e,b2=line(fn1,o1,l1)if not b1 then error(e)end
			b2,e=line(fn2,o2,l2)if not b2 then error(e)end
			return b1==b2 end return bin()end
	local function print_table()
		--TODO: store and reverse lookup this table to find the least amount of changes
		local il,jl=#f1//size,#f2//size
		for i=1,il do
			local row = {}
			for j=1,jl do table.insert(row,cmp(i,j) and "1" or "0")end
			print(table.concat(row, " "))end end
	print_table()
end
if#arg<2 or#arg%2~=0 then print(arg[-1].." "..arg[0]..[[ old new...

Compare differences between files, print them as unified context.
To compare multiple files,write them sequentially.
Example: ']]..arg[0]..[[ old1 new1 old2 new2 old3 new3' etc...]])os.exit(1)end
for i=0,255 do local c=i for _=1,8 do c=(c&1~=0)and((c>>1)~0xEDB88320)or(c>>1)end CT[i]=c end
for i=1,#arg,2 do diff_u(arg[i],arg[i+1])end
