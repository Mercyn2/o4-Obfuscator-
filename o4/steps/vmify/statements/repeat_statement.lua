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
    -- Note: we deliberately don't runtime-free upvalue boxes here (via
    -- freeUpvalVar) even for variables marked isUpvalue. A closure created
    -- during this iteration may have captured this box and can still be
    -- called after the loop exits (e.g. stored in a table) -- freeing the
    -- box here would wipe that value out from under it. Just clear the
    -- local register that held the box id/value.
    self:addStatement(self:setRegister(scope, varReg, A.NilExpression()), {varReg}, {}, false)
    self:freeRegister(varReg, true)
  end
  self:_setActiveBlock(finalBlock)
end
