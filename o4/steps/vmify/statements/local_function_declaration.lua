local A = require "ast"
return function(self, stmt, funcDepth)
  local scope = self.activeBlock.scope
  if self:isUpvalue(stmt.scope, stmt.id) then
    local varReg = self:getVarRegister(stmt.scope, stmt.id, funcDepth, nil)
    scope:addReferenceToHigherScope(self.scope, self.allocUpvalVar)
    self:addStatement(self:setRegister(scope, varReg, A.FunctionCallExpression(A.VariableExpression(self.scope, self.allocUpvalVar), {})), {varReg}, {}, false)
    -- This upvalue box stores a closure that may reference itself (recursion).
    -- The block-exit cleanup pass frees upvalue boxes based on lexical scope,
    -- but the closure can still be invoked *after* the declaring statement
    -- (e.g. `local function f() ... f() ... end f()` on the next line) --
    -- freeing the box there would wipe the self-reference before the
    -- recursive call ever runs. Mark it so compileBlock's cleanup skips it.
    self.noAutoFreeUpval = self.noAutoFreeUpval or {}
    self.noAutoFreeUpval[stmt.scope] = self.noAutoFreeUpval[stmt.scope] or {}
    self.noAutoFreeUpval[stmt.scope][stmt.id] = true
    local retReg = self:compileFunction(stmt, funcDepth)
    self:addStatement(self:setUpvalueMember(scope, self:register(scope, varReg), self:register(scope, retReg)), {}, {varReg, retReg}, true)
    self:freeRegister(retReg, false)
  else
    local retReg = self:compileFunction(stmt, funcDepth)
    local varReg = self:getVarRegister(stmt.scope, stmt.id, funcDepth, retReg)
    self:addStatement(self:copyRegisters(scope, {varReg}, {retReg}), {varReg}, {retReg}, false)
    self:freeRegister(retReg, false)
  end
end
