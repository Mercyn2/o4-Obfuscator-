local M={}
function M.lookupify(t)local o={}for _,v in ipairs(t)do o[v]=true end;return o end
function M.unlookupify(t)local o={}for v in pairs(t)do table.insert(o,v)end;return o end
function M.escape(s)return s:gsub(".",function(c)local b=string.byte(c)if b>=32 and b<=126 and c~="\\" and c~="\"" and c~="'" then return c end;if c=="\\" then return"\\\\" end;if c=="\n" then return"\\n" end;if c=="\r" then return"\\r" end;if c=="\"" then return"\\\"" end;if c=="'" then return"\\'" end;return string.format("\\%03d",b)end)end
function M.chararray(s)local t={}for i=1,#s do t[#t+1]=s:sub(i,i)end;return t end
function M.keys(t)local k,n={},0;for v in pairs(t)do n=n+1;k[n]=v end;return k end
function M.shuffle(t)for i=#t,2,-1 do local j=math.random(i);t[i],t[j]=t[j],t[i]end;return t end
function M.utf8char(cp)local sc=string.char;if cp<128 then return sc(cp)end;local s=cp%64;local c4=128+s;cp=(cp-s)/64;if cp<32 then return sc(192+cp,c4)end;local s2=cp%64;local c3=128+s2;cp=(cp-s2)/64;if cp<16 then return sc(224+cp,c3,c4)end;local s3=cp%64;cp=(cp-s3)/64;return sc(240+cp,128+s3,c3,c4)end
function M.readonly(obj)local r=newproxy(true);getmetatable(r).__index=obj;return r end
return M
