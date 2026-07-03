local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i == 1 then
      local b = self:compileExpression(expr.base,  funcDepth, 1)[1]
      local k = self:compileExpression(expr.index, funcDepth, 1)[1]
      self:addStatement(self:setRegister(scope, regs[i], A.IndexExpression(self:register(scope, b), self:register(scope, k))), {regs[i]}, {b, k}, true)
      self:freeRegister(b, false)
      self:freeRegister(k, false)
    else
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
