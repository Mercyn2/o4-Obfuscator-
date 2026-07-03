local A = require "ast"
return function(self, stmt, funcDepth)
  local scope      = self.activeBlock.scope
  local exprRegs   = {}
  local exprLen    = #stmt.expressions

  for i, expr in ipairs(stmt.expressions) do
    if i == exprLen and exprLen < 3 then
      local rs = self:compileExpression(expr, funcDepth, 4 - exprLen)
      for j = 1, 4 - exprLen do exprRegs[#exprRegs+1] = rs[j] end
    else
      if i <= 3 then
        exprRegs[#exprRegs+1] = self:compileExpression(expr, funcDepth, 1)[1]
      else
        self:freeRegister(self:compileExpression(expr, funcDepth, 1)[1], false)
      end
    end
  end

  for i, reg in ipairs(exprRegs) do
    if reg and self.registers[reg] ~= self.VAR_REGISTER and reg ~= self.POS_REGISTER and reg ~= self.RETURN_REGISTER then
      self.registers[reg] = self.VAR_REGISTER
    else
      exprRegs[i] = self:allocRegister(true)
      self:addStatement(self:copyRegisters(scope, {exprRegs[i]}, {reg}), {exprRegs[i]}, {reg}, false)
    end
  end

  local checkBlock = self:_createBlock()
  local bodyBlock  = self:_createBlock()
  local finalBlock = self:_createBlock()
  stmt.__start_block = checkBlock
  stmt.__final_block = finalBlock

  self:addStatement(self:setPos(scope, checkBlock.id), {self.POS_REGISTER}, {}, false)
  self:_setActiveBlock(checkBlock)
  scope = checkBlock.scope

  local varRegs = {}
  for i, id in ipairs(stmt.ids) do
    varRegs[i] = self:getVarRegister(stmt.scope, id, funcDepth)
  end

  self:addStatement(A.AssignmentStatement({
    self:registerAssignment(scope, exprRegs[3]),
    varRegs[2] and self:registerAssignment(scope, varRegs[2]) or self:registerAssignment(scope, self:allocRegister(false)),
  }, {
    A.FunctionCallExpression(self:register(scope, exprRegs[1]), {
      self:register(scope, exprRegs[2]),
      self:register(scope, exprRegs[3]),
    })
  }), {exprRegs[3], varRegs[2]}, {exprRegs[1], exprRegs[2], exprRegs[3]}, true)

  self:addStatement(A.AssignmentStatement(
    { self:posAssignment(scope) },
    { A.OrExpression(A.AndExpression(self:register(scope, exprRegs[3]), A.NumberExpression(bodyBlock.id)), A.NumberExpression(finalBlock.id)) }
  ), {self.POS_REGISTER}, {exprRegs[3]}, false)

  self:_setActiveBlock(bodyBlock)
  scope = bodyBlock.scope
  self:addStatement(self:copyRegisters(scope, {varRegs[1]}, {exprRegs[3]}), {varRegs[1]}, {exprRegs[3]}, false)
  for i = 3, #varRegs do
    self:addStatement(self:setRegister(scope, varRegs[i], A.NilExpression()), {varRegs[i]}, {}, false)
  end

  for i, id in ipairs(stmt.ids) do
    if self:isUpvalue(stmt.scope, id) then
      local vr = varRegs[i]
      local tmp = self:allocRegister(false)
      scope:addReferenceToHigherScope(self.scope, self.allocUpvalVar)
      self:addStatement(self:setRegister(scope, tmp, A.FunctionCallExpression(A.VariableExpression(self.scope, self.allocUpvalVar), {})), {tmp}, {}, false)
      self:addStatement(self:setUpvalueMember(scope, self:register(scope, tmp), self:register(scope, vr)), {}, {tmp, vr}, true)
      self:addStatement(self:copyRegisters(scope, {vr}, {tmp}), {vr}, {tmp}, false)
      self:freeRegister(tmp, false)
    end
  end

  self:compileBlock(stmt.body, funcDepth)
  self:addStatement(self:setPos(self.activeBlock.scope, checkBlock.id), {self.POS_REGISTER}, {}, false)
  self:_setActiveBlock(finalBlock)
  for _, r in ipairs(exprRegs) do self:freeRegister(r, true) end
end
