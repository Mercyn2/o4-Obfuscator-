local A  = require "ast"
local AK = A.AstKind
local unpack = unpack or table.unpack
return function(self, stmt, funcDepth)
  local scope   = self.activeBlock.scope
  local baseReg = self:compileExpression(stmt.base, funcDepth, 1)[1]
  local retReg  = self:allocRegister(false)
  local argRegs, args = {}, {}
  for i, a in ipairs(stmt.args) do
    if i == #stmt.args and (a.kind == AK.FunctionCallExpression or a.kind == AK.PassSelfFunctionCallExpression or a.kind == AK.VarargExpression) then
      local r = self:compileExpression(a, funcDepth, self.RETURN_ALL)[1]
      args[#args+1]    = A.FunctionCallExpression(self:unpack(scope), { self:register(scope, r) })
      argRegs[#argRegs+1] = r
    else
      local r = self:compileExpression(a, funcDepth, 1)[1]
      args[#args+1] = self:register(scope, r)
      argRegs[#argRegs+1] = r
    end
  end
  self:addStatement(self:setRegister(scope, retReg, A.FunctionCallExpression(self:register(scope, baseReg), args)), {retReg}, {baseReg, unpack(argRegs)}, true)
  self:freeRegister(baseReg, false)
  self:freeRegister(retReg, false)
  for _, r in ipairs(argRegs) do self:freeRegister(r, false) end
end
