local A = require "ast"
return function(self, stmt, funcDepth)
  local scope      = self.activeBlock.scope
  local checkBlock = self:_createBlock()
  local bodyBlock  = self:_createBlock()
  local finalBlock = self:_createBlock()
  stmt.__start_block = checkBlock
  stmt.__final_block = finalBlock

  self:addStatement(self:setPos(scope, checkBlock.id), {self.POS_REGISTER}, {}, false)
  self:_setActiveBlock(checkBlock)
  scope = checkBlock.scope
  local condReg = self:compileExpression(stmt.condition, funcDepth, 1)[1]
  self:addStatement(self:setRegister(scope, self.POS_REGISTER,
    A.OrExpression(A.AndExpression(self:register(scope, condReg), A.NumberExpression(bodyBlock.id)), A.NumberExpression(finalBlock.id))
  ), {self.POS_REGISTER}, {condReg}, false)
  self:freeRegister(condReg, false)

  self:_setActiveBlock(bodyBlock)
  self:compileBlock(stmt.body, funcDepth)
  self:addStatement(self:setPos(self.activeBlock.scope, checkBlock.id), {self.POS_REGISTER}, {}, false)
  self:_setActiveBlock(finalBlock)
end
