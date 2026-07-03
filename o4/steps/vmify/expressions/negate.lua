local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i == 1 then
      local r = self:compileExpression(expr.rhs, funcDepth, 1)[1]
      self:addStatement(self:setRegister(scope, regs[i], A.NegateExpression(self:register(scope, r))), {regs[i]}, {r}, true)
      self:freeRegister(r, false)
    else
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
