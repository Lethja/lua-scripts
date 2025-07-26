#!/usr/bin/env lua

local PF,CT,M="I2I4I8",{},0xFFFFFFFF
local function diff_u(fn1,fn2)
	local function open(fn)
		local f,e=io.open(fn, "rb")
		if not f then print(e)os.exit(1)end
		local o,p=0,""
		local function crc32(s)local c=M for i=1,#s do local byte=s:byte(i)c=(c >> 8)~CT[(c~byte)&0xFF]end return(~c)&M end
		while true do local ls,l=o,{}
			while true do local c = f:read(1)if not c then break end
				local function eol()if c=='\r'then local d=f:read(1)f:seek("cur",-1)return d~='\n'end return c=='\n'end
				o=o+1 table.insert(l,c)if eol()then break end end
			if #l==0 then break end l=table.concat(l)local ln,c=#l,crc32(l)p=p..string.pack(PF,ln,c,ls)end
		f:close()return p end
	--TODO: Replace this code with myers algorithm
	local f1,f2,size=open(fn1),open(fn2),string.packsize(PF)
	local function printFile(f)local len=#f//size
		for i=1,len do local length,crc,offset=string.unpack(PF,f,(i-1)*size+1)
			print(("Offset: %06d | Length: %03d | CRC32: %08X"):format(offset,length,crc))end end
	printFile(f1)
	printFile(f2)
end
if#arg<2 or#arg%2~=0 then print(arg[-1].." "..arg[0]..[[ old new...

Compare differences between files, print them as unified context.
To compare multiple files,write them sequentially.
Example: ']]..arg[0]..[[ old1 new1 old2 new2 old3 new3' etc...]])os.exit(1)end
for i=0,255 do local c=i for _=1,8 do c=(c&1~=0)and((c>>1)~0xEDB88320)or(c>>1)end CT[i]=c end
for i=1,#arg,2 do diff_u(arg[i],arg[i+1])end
