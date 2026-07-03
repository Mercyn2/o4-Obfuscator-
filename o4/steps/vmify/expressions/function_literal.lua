local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    if i == 1 then
      regs[i] = self:compileFunction(expr, funcDepth)
    else
      regs[i] = self:allocRegister()
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
