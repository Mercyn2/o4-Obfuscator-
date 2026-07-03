local A  = require "ast"
local U  = require "util"
return function(self, stmt, funcDepth)
  local scope      = self.activeBlock.scope
  local checkBlock = self:_createBlock()
  local innerBlock = self:_createBlock()
  local finalBlock = self:_createBlock()
  stmt.__start_block = checkBlock
  stmt.__final_block = finalBlock

  local posState = self.registers[self.POS_REGISTER]
  self.registers[self.POS_REGISTER] = self.VAR_REGISTER

  local initReg  = self:compileExpression(stmt.initialValue, funcDepth, 1)[1]
  local finTmpReg= self:compileExpression(stmt.finalValue,   funcDepth, 1)[1]
  local finReg   = self:allocRegister(false)
  self:addStatement(self:copyRegisters(scope, {finReg}, {finTmpReg}), {finReg}, {finTmpReg}, false)
  self:freeRegister(finTmpReg)

  local incTmpReg = self:compileExpression(stmt.incrementBy, funcDepth, 1)[1]
  local incReg    = self:allocRegister(false)
  self:addStatement(self:copyRegisters(scope, {incReg}, {incTmpReg}), {incReg}, {incTmpReg}, false)
  self:freeRegister(incTmpReg)

  -- isNeg = incReg < 0
  local zeroReg  = self:allocRegister(false)
  local isNegReg = self:allocRegister(false)
  self:addStatement(self:setRegister(scope, zeroReg, A.NumberExpression(0)), {zeroReg}, {}, false)
  self:addStatement(self:setRegister(scope, isNegReg, A.LessThanExpression(self:register(scope, incReg), self:register(scope, zeroReg))), {isNegReg}, {incReg, zeroReg}, false)
  self:freeRegister(zeroReg)

  local curReg = self:allocRegister(true)
  self:addStatement(self:setRegister(scope, curReg, A.SubExpression(self:register(scope, initReg), self:register(scope, incReg))), {curReg}, {initReg, incReg}, false)
  self:freeRegister(initReg)
  self:addStatement(self:jmp(scope, A.NumberExpression(checkBlock.id)), {self.POS_REGISTER}, {}, false)

  self:_setActiveBlock(checkBlock)
  scope = checkBlock.scope
  -- cur = cur + inc
  local sh = U.shuffle({curReg, incReg})
  self:addStatement(self:setRegister(scope, curReg, A.AddExpression(self:register(scope, sh[1]), self:register(scope, sh[2]))), {curReg}, {sh[1], sh[2]}, false)

  -- fwd = (not isNeg) and cur <= fin
  local t1 = self:allocRegister(false); local t2 = self:allocRegister(false)
  self:addStatement(self:setRegister(scope, t2, A.NotExpression(self:register(scope, isNegReg))), {t2}, {isNegReg}, false)
  self:addStatement(self:setRegister(scope, t1, A.LessThanOrEqualsExpression(self:register(scope, curReg), self:register(scope, finReg))), {t1}, {curReg, finReg}, false)
  self:addStatement(self:setRegister(scope, t1, A.AndExpression(self:register(scope, t2), self:register(scope, t1))), {t1}, {t1, t2}, false)
  -- rev = isNeg and cur >= fin
  self:addStatement(self:setRegister(scope, t2, A.GreaterThanOrEqualsExpression(self:register(scope, curReg), self:register(scope, finReg))), {t2}, {curReg, finReg}, false)
  self:addStatement(self:setRegister(scope, t2, A.AndExpression(self:register(scope, isNegReg), self:register(scope, t2))), {t2}, {t2, isNegReg}, false)
  self:addStatement(self:setRegister(scope, t1, A.OrExpression(self:register(scope, t2), self:register(scope, t1))), {t1}, {t1, t2}, false)
  self:freeRegister(t2)
  -- pos = t1 and innerBlock.id or finalBlock.id
  local innIdReg = self:compileExpression(A.NumberExpression(innerBlock.id), funcDepth, 1)[1]
  self:addStatement(self:setRegister(scope, self.POS_REGISTER, A.AndExpression(self:register(scope, t1), self:register(scope, innIdReg))), {self.POS_REGISTER}, {t1, innIdReg}, false)
  self:freeRegister(innIdReg)
  local finIdReg = self:compileExpression(A.NumberExpression(finalBlock.id), funcDepth, 1)[1]
  self:addStatement(self:setRegister(scope, self.POS_REGISTER, A.OrExpression(self:register(scope, self.POS_REGISTER), self:register(scope, finIdReg))), {self.POS_REGISTER}, {self.POS_REGISTER, finIdReg}, false)
  self:freeRegister(finIdReg)
  self:freeRegister(t1)

  self:_setActiveBlock(innerBlock)
  scope = innerBlock.scope
  self.registers[self.POS_REGISTER] = posState

  local varReg = self:getVarRegister(stmt.scope, stmt.id, funcDepth, nil)
  if self:isUpvalue(stmt.scope, stmt.id) then
    scope:addReferenceToHigherScope(self.scope, self.allocUpvalVar)
    self:addStatement(self:setRegister(scope, varReg, A.FunctionCallExpression(A.VariableExpression(self.scope, self.allocUpvalVar), {})), {varReg}, {}, false)
    self:addStatement(self:setUpvalueMember(scope, self:register(scope, varReg), self:register(scope, curReg)), {}, {varReg, curReg}, true)
  else
    self:addStatement(self:setRegister(scope, varReg, self:register(scope, curReg)), {varReg}, {curReg}, false)
  end

  self:compileBlock(stmt.body, funcDepth)
  self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER, A.NumberExpression(checkBlock.id)), {self.POS_REGISTER}, {}, false)

  self.registers[self.POS_REGISTER] = self.VAR_REGISTER
  self:freeRegister(finReg); self:freeRegister(isNegReg); self:freeRegister(incReg)
  self:freeRegister(curReg, true)
  self.registers[self.POS_REGISTER] = posState
  self:_setActiveBlock(finalBlock)
end
