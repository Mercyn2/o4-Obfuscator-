local A  = require "ast"
local AK = A.AstKind
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    if i == 1 then
      if expr.scope.isGlobal then
        regs[i] = self:allocRegister(false)
        local tmp = self:allocRegister(false)
        self:addStatement(self:setRegister(scope, tmp, A.StringExpression(expr.scope:getVariableName(expr.id))), {tmp}, {}, false)
        self:addStatement(self:setRegister(scope, regs[i], A.IndexExpression(self:env(scope), self:register(scope, tmp))), {regs[i]}, {tmp}, true)
        self:freeRegister(tmp, false)
      else
        if self.scopeFunctionDepths[expr.scope] == funcDepth then
          if self:isUpvalue(expr.scope, expr.id) then
            local reg    = self:allocRegister(false)
            local varReg = self:getVarRegister(expr.scope, expr.id, funcDepth, nil)
            self:addStatement(self:setRegister(scope, reg, self:getUpvalueMember(scope, self:register(scope, varReg))), {reg}, {varReg}, true)
            regs[i] = reg
          else
            regs[i] = self:getVarRegister(expr.scope, expr.id, funcDepth, nil)
          end
        else
          local reg     = self:allocRegister(false)
          local upvalId = self:getUpvalueId(expr.scope, expr.id)
          scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
          self:addStatement(self:setRegister(scope, reg,
            self:getUpvalueMember(scope,
              A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar), A.NumberExpression(upvalId))
            )
          ), {reg}, {}, true)
          regs[i] = reg
        end
      end
    else
      regs[i] = self:allocRegister()
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
