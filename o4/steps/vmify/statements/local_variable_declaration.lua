local A  = require "ast"
local AK = A.AstKind
return function(self, stmt, funcDepth)
  local scope   = self.activeBlock.scope
  local exprRegs = {}
  for i, expr in ipairs(stmt.expressions) do
    if i == #stmt.expressions and #stmt.ids > #stmt.expressions then
      local rs = self:compileExpression(expr, funcDepth, #stmt.ids - #stmt.expressions + 1)
      for _, r in ipairs(rs) do exprRegs[#exprRegs+1] = r end
    else
      if stmt.ids[i] or expr.kind == AK.FunctionCallExpression or expr.kind == AK.PassSelfFunctionCallExpression then
        exprRegs[#exprRegs+1] = self:compileExpression(expr, funcDepth, 1)[1]
      end
    end
  end
  if #exprRegs == 0 then
    for _ = 1, #stmt.ids do
      exprRegs[#exprRegs+1] = self:compileExpression(A.NilExpression(), funcDepth, 1)[1]
    end
  end
  for i, id in ipairs(stmt.ids) do
    if exprRegs[i] then
      if self:isUpvalue(stmt.scope, id) then
        local varReg = self:getVarRegister(stmt.scope, id, funcDepth, nil)
        scope:addReferenceToHigherScope(self.scope, self.allocUpvalVar)
        self:addStatement(self:setRegister(scope, varReg, A.FunctionCallExpression(A.VariableExpression(self.scope, self.allocUpvalVar), {})), {varReg}, {}, false)
        self:addStatement(self:setUpvalueMember(scope, self:register(scope, varReg), self:register(scope, exprRegs[i])), {}, {varReg, exprRegs[i]}, true)
        self:freeRegister(exprRegs[i], false)
      else
        local varReg = self:getVarRegister(stmt.scope, id, funcDepth, exprRegs[i])
        self:addStatement(self:copyRegisters(scope, {varReg}, {exprRegs[i]}), {varReg}, {exprRegs[i]}, false)
        self:freeRegister(exprRegs[i], false)
      end
    end
  end
  if not self.scopeFunctionDepths[stmt.scope] then
    self.scopeFunctionDepths[stmt.scope] = funcDepth
  end
end
