local logger = require "logger"
local Parser = require "parser"
local Unparser = require "unparser"
local E = require "enums"
local ConstantArray = require "steps.constarray"
local EncryptStrings = require "steps.encrypt"
local NumbersToExpressions = require "steps.numbers"
local WrapInFunction = require "steps.wrap"
local Vmify = require "steps.vmify"
local U = require "util"
local shuffle = U.shuffle

local VD = {
  "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
  "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
  "0","1","2","3","4","5","6","7","8","9","_"
}
local VS = {
  "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
  "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
}

local function mangledName(id)
  local name = ""
  local d = id % #VS
  id = (id - d) / #VS
  name = name .. VS[d + 1]
  while id > 0 do
    local e = id % #VD
    id = (id - e) / #VD
    name = name .. VD[e + 1]
  end
  return name
end

local NG = {
  generateName = mangledName,
  prepare = function() shuffle(VD); shuffle(VS) end
}

return function(code, filename)
  filename = filename or "Anonymous"
  logger:info("Applying pipeline to " .. filename .. " ...")

  local ok, seed = pcall(function()
    local s = io.popen("openssl rand -hex 12"):read("*a"):gsub("\n", "")
    local n = 0
    for i = 1, #s do
      local c = s:sub(i, i):lower()
      local d = c:match("%d") and (c:byte() - 48) or (c:byte() - 87)
      n = n * 16 + d
    end
    if _VERSION == "Lua 5.1" and not jit then
      n = n % 9.007199254741e+15
    end
    return n
  end)

  if ok then
    math.randomseed(seed)
  else
    logger:warn("OpenSSL unavailable, using os.time")
    math.randomseed(os.time())
  end

  local t0 = os.time()
  local srcLen = #code

  logger:info("Parsing...")
  local parser = Parser:new({ LuaVersion = "Lua51" })
  local ast = parser:parse(code)
  logger:info("Parsing done")

  local steps = {
    Vmify:new({}),
    ConstantArray:new({
      Treshold = 1,
      StringsOnly = true,
      Shuffle = true,
      Rotate = true,
      Encoding = "base64",
      LocalWrapperCount = 0,
      LocalWrapperArgCount = 10,
      MaxWrapperOffset = 65535,
      LocalWrapperTreshold = 0,
    }),
    EncryptStrings:new({}),
    NumbersToExpressions:new({
      Threshold = 1,
      InternalThreshold = 0.2,
      NumberRepresentationMutaton = false,
      AllowedNumberRepresentations = { "hex", "scientific", "normal" },
    }),
    WrapInFunction:new({ Iterations = 1 }),
  }

  for _, step in ipairs(steps) do
    logger:info("Applying step \"" .. step.Name .. "\" ...")
    local t1 = os.time()
    local newAst = step:apply(ast)
    if type(newAst) == "table" then ast = newAst end
    logger:info("Step \"" .. step.Name .. "\" done in " .. (os.time() - t1) .. " s")
  end

  logger:info("Renaming variables...")
  local t1 = os.time()
  if type(NG.prepare) == "function" then NG.prepare(ast) end
  local conv = E.Conventions["Lua51"]
  ast.globalScope:renameVariables({
    Keywords = conv.Keywords,
    generateName = NG.generateName,
    prefix = "",
  })
  logger:info("Rename done in " .. (os.time() - t1) .. " s")

  logger:info("Generating code...")
  t1 = os.time()
  local unparser = Unparser:new({ LuaVersion = "Lua51", PrettyPrint = false })
  local out = unparser:unparse(ast)
  logger:info("Code gen done in " .. (os.time() - t1) .. " s")
  logger:info("Done in " .. (os.time() - t0) .. " s | Output is " .. string.format("%.2f", (#out / srcLen) * 100) .. "% of source")

  return out
end
