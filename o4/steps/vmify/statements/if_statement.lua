local A = require "ast"
return function(self, stmt, funcDepth)
  local scope      = self.activeBlock.scope
  local condReg    = self:compileExpression(stmt.condition, funcDepth, 1)[1]
  local finalBlock = self:_createBlock()
  local nextBlock
  if stmt.elsebody or #stmt.elseifs > 0 then
    nextBlock = self:_createBlock()
  else
    nextBlock = finalBlock
  end
  local innerBlock = self:_createBlock()

  self:addStatement(self:setRegister(scope, self.POS_REGISTER,
    A.OrExpression(A.AndExpression(self:register(scope, condReg), A.NumberExpression(innerBlock.id)), A.NumberExpression(nextBlock.id))
  ), {self.POS_REGISTER}, {condReg}, false)
  self:freeRegister(condReg, false)

  self:_setActiveBlock(innerBlock)
  self:compileBlock(stmt.body, funcDepth)
  self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER, A.NumberExpression(finalBlock.id)), {self.POS_REGISTER}, {}, false)

  for i, eif in ipairs(stmt.elseifs) do
    self:_setActiveBlock(nextBlock)
    condReg = self:compileExpression(eif.condition, funcDepth, 1)[1]
    local eifInner = self:_createBlock()
    if stmt.elsebody or i < #stmt.elseifs then
      nextBlock = self:_createBlock()
    else
      nextBlock = finalBlock
    end
    scope = self.activeBlock.scope
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
      A.OrExpression(A.AndExpression(self:register(scope, condReg), A.NumberExpression(eifInner.id)), A.NumberExpression(nextBlock.id))
    ), {self.POS_REGISTER}, {condReg}, false)
    self:freeRegister(condReg, false)
    self:_setActiveBlock(eifInner)
    self:compileBlock(eif.body, funcDepth)
    self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER, A.NumberExpression(finalBlock.id)), {self.POS_REGISTER}, {}, false)
  end

  if stmt.elsebody then
    self:_setActiveBlock(nextBlock)
    self:compileBlock(stmt.elsebody, funcDepth)
    self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER, A.NumberExpression(finalBlock.id)), {self.POS_REGISTER}, {}, false)
  end

  self:_setActiveBlock(finalBlock)
end
