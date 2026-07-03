local A  = require "ast"
local AK = A.AstKind
local unpack = unpack or table.unpack
return function(self, expr, funcDepth, n)
  local scope     = self.activeBlock.scope
  local baseReg   = self:compileExpression(expr.base, funcDepth, 1)[1]
  local returnAll = (n == self.RETURN_ALL)
  local retRegs   = {}
  if returnAll then
    retRegs[1] = self:allocRegister(false)
  else
    for i = 1, n do retRegs[i] = self:allocRegister(false) end
  end

  local argRegs, args = {}, {}
  for i, a in ipairs(expr.args) do
    if i == #expr.args and (a.kind == AK.FunctionCallExpression or a.kind == AK.PassSelfFunctionCallExpression or a.kind == AK.VarargExpression) then
      local r = self:compileExpression(a, funcDepth, self.RETURN_ALL)[1]
      args[#args+1]    = A.FunctionCallExpression(self:unpack(scope), { self:register(scope, r) })
      argRegs[#argRegs+1] = r
    else
      local r = self:compileExpression(a, funcDepth, 1)[1]
      args[#args+1]    = self:register(scope, r)
      argRegs[#argRegs+1] = r
    end
  end

  local baseExpr = self:register(scope, baseReg)
  local callExpr = A.FunctionCallExpression(baseExpr, args)

  if returnAll or n > 1 then
    local tmpReg = self:allocRegister(false)
    self:addStatement(self:setRegister(scope, tmpReg, A.TableConstructorExpression({ A.TableEntry(callExpr) })), {tmpReg}, {baseReg, unpack(argRegs)}, true)
    if returnAll then
      self:setRegister(scope, retRegs[1], self:register(scope, tmpReg)) -- just pass tmpReg
      retRegs[1] = tmpReg
    else
      for i, reg in ipairs(retRegs) do
        self:addStatement(self:setRegister(scope, reg, A.IndexExpression(self:register(scope, tmpReg), A.NumberExpression(i))), {reg}, {tmpReg}, false)
      end
      self:freeRegister(tmpReg, false)
    end
  else
    self:addStatement(self:setRegister(scope, retRegs[1], callExpr), {retRegs[1]}, {baseReg, unpack(argRegs)}, true)
  end

  self:freeRegister(baseReg, false)
  for _, r in ipairs(argRegs) do self:freeRegister(r, false) end
  return retRegs
end
