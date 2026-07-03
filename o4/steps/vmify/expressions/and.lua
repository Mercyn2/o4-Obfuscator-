local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope    = self.activeBlock.scope
  local posState = self.registers[self.POS_REGISTER]
  self.registers[self.POS_REGISTER] = self.VAR_REGISTER

  local regs = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i ~= 1 then
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  local resReg = regs[1]
  local tmpReg
  if posState then
    tmpReg = self:allocRegister(false)
    self:addStatement(self:copyRegisters(scope, {tmpReg}, {self.POS_REGISTER}), {tmpReg}, {self.POS_REGISTER}, false)
  end

  local lhsReg = self:compileExpression(expr.lhs, funcDepth, 1)[1]
  if expr.rhs.isConstant then
    local rhsReg = self:compileExpression(expr.rhs, funcDepth, 1)[1]
    self:addStatement(self:setRegister(scope, resReg, A.AndExpression(self:register(scope, lhsReg), self:register(scope, rhsReg))), {resReg}, {lhsReg, rhsReg}, false)
    if tmpReg then self:freeRegister(tmpReg, false) end
    self:freeRegister(lhsReg, false); self:freeRegister(rhsReg, false)
    return regs
  end

  local b1, b2 = self:_createBlock(), self:_createBlock()
  self:addStatement(self:copyRegisters(scope, {resReg}, {lhsReg}), {resReg}, {lhsReg}, false)
  self:addStatement(self:setRegister(scope, self.POS_REGISTER,
    A.OrExpression(A.AndExpression(self:register(scope, lhsReg), A.NumberExpression(b1.id)), A.NumberExpression(b2.id))
  ), {self.POS_REGISTER}, {lhsReg}, false)
  self:freeRegister(lhsReg, false)

  self:_setActiveBlock(b1)
  scope = b1.scope
  local rhsReg = self:compileExpression(expr.rhs, funcDepth, 1)[1]
  self:addStatement(self:copyRegisters(scope, {resReg}, {rhsReg}), {resReg}, {rhsReg}, false)
  self:freeRegister(rhsReg, false)
  self:addStatement(self:setRegister(scope, self.POS_REGISTER, A.NumberExpression(b2.id)), {self.POS_REGISTER}, {}, false)

  self.registers[self.POS_REGISTER] = posState
  self:_setActiveBlock(b2)
  scope = b2.scope
  if tmpReg then
    self:addStatement(self:copyRegisters(scope, {self.POS_REGISTER}, {tmpReg}), {self.POS_REGISTER}, {tmpReg}, false)
    self:freeRegister(tmpReg, false)
  end
  return regs
end
