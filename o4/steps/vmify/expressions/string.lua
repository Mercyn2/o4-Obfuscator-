local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i == 1 then
      self:addStatement(self:setRegister(scope, regs[i], A.StringExpression(expr.value)), {regs[i]}, {}, false)
    else
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
