local U=require"util"
local ca=U.chararray
local E={}
E.LuaVersion={LuaU="LuaU",Lua51="Lua51"}
local base={
  SymbolChars=ca("+-*/%^#=~<>(){}[];:,."),MaxSymbolLength=3,
  IdentChars=ca("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
  NumberChars=ca("0123456789"),HexNumberChars=ca("0123456789abcdefABCDEF"),
  BinaryNumberChars={"0","1"},DecimalExponent={"e","E"},HexadecimalNums={"x","X"},
  BinaryNums={"b","B"},DecimalSeperators=false,
  EscapeSequences={["a"]="\\a",["b"]="\\b",["f"]="\\f",["n"]="\\n",["r"]="\\r",["t"]="\\t",["v"]="\\v",["\\"]="\\",["\""]="\"",["'"]="'"},
  NumericalEscapes=true,EscapeZIgnoreNextWhitespace=true,HexEscapes=true,UnicodeEscapes=true,
}
E.Conventions={
  Lua51=setmetatable({Keywords={"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while"},Symbols={"+","-","*","/","%","^","#","==","~=","<=",">=","<",">","=","(",")","[","]","{","}",";",":",",",".","..","..."}},{__index=base}),
  LuaU=setmetatable({Keywords={"and","break","continue","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while"},DecimalSeperators={"_"},Symbols={"+","-","*","/","%","^","#","==","~=","<=",">=","<",">","=","+=","-=","*=","/=","%=","^=","..=","(",")","[","]","{","}",";",":",",",".","..","...","::","->","?","|","&"}},{__index=base}),
}
return E
