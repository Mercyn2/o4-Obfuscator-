local A = require "ast"
return function(self, stmt, funcDepth)
  local scope      = self.activeBlock.scope
  local bodyBlock  = self:_createBlock()
  local finalBlock = self:_createBlock()
  stmt.__start_block = bodyBlock
  stmt.__final_block = finalBlock

  self:addStatement(self:setPos(scope, bodyBlock.id), {self.POS_REGISTER}, {}, false)
  self:_setActiveBlock(bodyBlock)

  for _, s in ipairs(stmt.body.statements) do self:compileStatement(s, funcDepth) end

  scope = self.activeBlock.scope
  local condReg = self:compileExpression(stmt.condition, funcDepth, 1)[1]
  self:addStatement(self:setRegister(scope, self.POS_REGISTER,
    A.OrExpression(A.AndExpression(self:register(scope, condReg), A.NumberExpression(finalBlock.id)), A.NumberExpression(bodyBlock.id))
  ), {self.POS_REGISTER}, {condReg}, false)
  self:freeRegister(condReg, false)

  for id in ipairs(stmt.body.scope.variables) do
    local varReg = self:getVarRegister(stmt.body.scope, id, funcDepth, nil)
    if self:isUpvalue(stmt.body.scope, id) then
      scope:addReferenceToHigherScope(self.scope, self.freeUpvalVar)
      self:addStatement(self:setRegister(scope, varReg, A.FunctionCallExpression(A.VariableExpression(self.scope, self.freeUpvalVar), { self:register(scope, varReg) })), {varReg}, {varReg}, false)
    else
      self:addStatement(self:setRegister(scope, varReg, A.NilExpression()), {varReg}, {}, false)
    end
    self:freeRegister(varReg, true)
  end
  self:_setActiveBlock(finalBlock)
end
