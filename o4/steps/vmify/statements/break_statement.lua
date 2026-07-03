local A = require "ast"
return function(self, stmt, funcDepth)
  local scope      = self.activeBlock.scope
  local toFree     = {}
  local statScope
  repeat
    statScope = statScope and statScope.parentScope or stmt.scope
    for id in ipairs(statScope.variables) do
      toFree[#toFree+1] = { scope = statScope, id = id }
    end
  until statScope == stmt.loop.body.scope

  for _, v in ipairs(toFree) do
    local varReg = self:getVarRegister(v.scope, v.id, nil, nil)
    if self:isUpvalue(v.scope, v.id) then
      scope:addReferenceToHigherScope(self.scope, self.freeUpvalVar)
      self:addStatement(self:setRegister(scope, varReg, A.FunctionCallExpression(A.VariableExpression(self.scope, self.freeUpvalVar), { self:register(scope, varReg) })), {varReg}, {varReg}, false)
    else
      self:addStatement(self:setRegister(scope, varReg, A.NilExpression()), {varReg}, {}, false)
    end
  end
  self:addStatement(self:setPos(scope, stmt.loop.__final_block.id), {self.POS_REGISTER}, {}, false)
  self.activeBlock.advanceToNextBlock = false
end
