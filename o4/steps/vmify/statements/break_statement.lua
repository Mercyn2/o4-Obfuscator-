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
    -- Note: we deliberately don't runtime-free upvalue boxes here (via
    -- freeUpvalVar) even for variables marked isUpvalue. A closure created
    -- earlier in this iteration may have captured this box and can still
    -- be called after the loop exits (e.g. stored in a table) -- freeing
    -- the box here would wipe that value out from under it. Just clear
    -- the local register that held the box id/value.
    self:addStatement(self:setRegister(scope, varReg, A.NilExpression()), {varReg}, {}, false)
  end
  self:addStatement(self:setPos(scope, stmt.loop.__final_block.id), {self.POS_REGISTER}, {}, false)
  self.activeBlock.advanceToNextBlock = false
end
