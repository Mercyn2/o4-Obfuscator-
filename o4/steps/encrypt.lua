 
local Step=require"step";local A=require"ast";local S=require"scope";local Parser=require"parser";local V=require"visit";local U=require"util"
 
local AK=A.AstKind;local visitAst=V.visitAst;local shuffle=U.shuffle
 
local E=Step:extend()
 
E.Name="Encrypt Strings"
 
E.Description="Encrypts all string literals"
 
E.SettingsDescriptor={}
 
function E:init()end
 
 
function E:CreateEncryptionService()
 
  local usedSeeds={}
 
  local sk6=math.random(0,63)
 
  local sk7=math.random(0,127)
 
  local sk44=math.random(0,2147483647)
 
  local sk8=math.random(0,255)
 
  local floor=math.floor
 
  local function proot257(idx)
 
    local g,m,d=1,128,2*idx+1
 
    repeat g,m,d=g*g*(d>=m and 3 or 1)%257,m/2,d%m until m<1
 
    return g
 
  end
 
  local pm8=proot257(sk7)
 
  local pm45=sk6*4+1
 
  local pa45=sk44*2+1
 
  local s45=0;local s8=2;local prevVals={}
 
  local function setSeed(seed)
 
    s45=seed%35184372088832;s8=seed%255+2;prevVals={}
 
  end
 
  local function genSeed()
 
    local s
 
    repeat s=math.random(0,2147483647)until not usedSeeds[s]
 
    usedSeeds[s]=true;return s
 
  end
 
  local function getRand32()
 
    s45=(s45*pm45+pa45)%35184372088832
 
    repeat s8=s8*pm8%257 until s8~=1
 
    local r=s8%32
 
    local n=floor(s45/2^(13-(s8-r)/32))%2^32/2^r
 
    return floor(n%1*2^32)+floor(n)
 
  end
 
  local function nextByte()
 
    if #prevVals==0 then
 
      local rnd=getRand32()
 
      local lo=rnd%65536;local hi=(rnd-lo)/65536
 
      local b1=lo%256;local b2=(lo-b1)/256
 
      local b3=hi%256;local b4=(hi-b3)/256
 
      prevVals={b1,b2,b3,b4}
 
    end
 
    return table.remove(prevVals)
 
  end
 
  local function encrypt(str)
 
    local seed=genSeed();setSeed(seed)
 
    local len=#str;local out={};local prev=sk8
 
    for i=1,len do
 
      local b=string.byte(str,i)
 
      out[i]=string.char((b-(nextByte()+prev))%256)
 
      prev=b
 
    end
 
    return table.concat(out),seed
 
  end
 
  local function genCode()
 
    return string.format([[
 
do
 
local floor = math.floor
 
local remove = table.remove
 
local char = string.char
 
local state_45 = 0
 
local state_8 = 2
 
local charmap = {}
 
local nums = {}
 
for i = 1, 256 do
 
    nums[i] = i
 
end
 
repeat
 
    local idx = math.random(1, #nums)
 
    local n = remove(nums, idx)
 
    charmap[n] = char(n - 1)
 
until #nums == 0
 
local prev_values = {}
 
local function get_next()
 
    if #prev_values == 0 then
 
        state_45 = (state_45 * %d + %d) %% 35184372088832
 
        repeat
 
            state_8 = state_8 * %d %% 257
 
        until state_8 ~= 1
 
        local r = state_8 %% 32
 
        local shift = 13 - (state_8 - r) / 32
 
        local n = floor(state_45 / 2^shift) %% 4294967296 / 2^r
 
        local rnd = floor(n %% 1 * 4294967296) + floor(n)
 
        local lo = rnd %% 65536
 
        local hi = (rnd - lo) / 65536
 
        prev_values = {lo%%256, (lo-lo%%256)/256, hi%%256, (hi-hi%%256)/256}
 
    end
 
    local pv = #prev_values
 
    local v = prev_values[pv]
 
    prev_values[pv] = nil
 
    return v
 
end
 
local realStrings = {}
 
STRINGS = setmetatable({}, {__index = realStrings, __metatable = nil})
 
function DECRYPT(str, seed)
 
    local rs = realStrings
 
    if rs[seed] then
 
        return seed
 
    else
 
        prev_values = {}
 
        local chars = charmap
 
        state_45 = seed %% 35184372088832
 
        state_8 = seed %% 255 + 2
 
        local len = #str
 
        rs[seed] = ""
 
        local prev = %d
 
        local s = ""
 
        for i = 1, len do
 
            prev = (string.byte(str, i) + get_next() + prev) %% 256
 
            s = s .. chars[prev + 1]
 
        end
 
        rs[seed] = s
 
    end
 
    return seed
 
end
 
end
 
]], pm45, pa45, pm8, sk8)
 
  end
 
  return {encrypt=encrypt, genCode=genCode}
 
end
 
 
 function E:apply(ast)
 
  local enc=self:CreateEncryptionService()
 
  local code=enc.genCode()
 
  
 
  local parser=Parser:new({LuaVersion="Lua51"})
 
  local newAst=parser:parse(code)
 
  local doStat=newAst.body.statements[1]
 
  local scope=ast.body.scope
 
  local decryptVar=scope:addVariable()
 
  local stringsVar=scope:addVariable()
 
  doStat.body.scope:setParent(ast.body.scope)
 
  visitAst(newAst,nil,function(node,data)
 
    if node.kind==AK.FunctionDeclaration then
 
      if node.scope:getVariableName(node.id)=="DECRYPT" then
 
        data.scope:removeReferenceToHigherScope(node.scope,node.id)
 
        data.scope:addReferenceToHigherScope(scope,decryptVar)
 
        node.scope=scope;node.id=decryptVar
 
      end
 
    end
 
    if node.kind==AK.AssignmentVariable or node.kind==AK.VariableExpression then
 
      if node.scope:getVariableName(node.id)=="STRINGS" then
 
        data.scope:removeReferenceToHigherScope(node.scope,node.id)
 
        data.scope:addReferenceToHigherScope(scope,stringsVar)
 
        node.scope=scope;node.id=stringsVar
 
      end
 
    end
 
  end)
 
  visitAst(ast,nil,function(node,data)
 
    if node.kind==AK.StringExpression then
 
      data.scope:addReferenceToHigherScope(scope,stringsVar)
 
      data.scope:addReferenceToHigherScope(scope,decryptVar)
 
      local encrypted,seed=enc.encrypt(node.value)
 
      return A.IndexExpression(
 
        A.VariableExpression(scope,stringsVar),
 
        A.FunctionCallExpression(A.VariableExpression(scope,decryptVar),{
 
          A.StringExpression(encrypted),
 
          A.NumberExpression(seed),
 
        })
 
      )
 
    end
 
  end)
 
  table.insert(ast.body.statements,1,doStat)
 
  table.insert(ast.body.statements,1,
 
    A.LocalVariableDeclaration(scope,shuffle{decryptVar,stringsVar},{}))
 
  return ast
 
end
 
 
return E
 

