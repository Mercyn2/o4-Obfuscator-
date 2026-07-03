local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  if n == self.RETURN_ALL then
    return { self.varargReg }
  end
  local regs = {}
  for i = 1, n do
    regs[i] = self:allocRegister(false)
    self:addStatement(self:setRegister(scope, regs[i],
      A.IndexExpression(self:register(scope, self.varargReg), A.NumberExpression(i))
    ), {regs[i]}, {self.varargReg}, false)
  end
  return regs
end
