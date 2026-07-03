local A = require "ast"
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i == 1 then
      local l = self:compileExpression(expr.lhs, funcDepth, 1)[1]
      local r = self:compileExpression(expr.rhs, funcDepth, 1)[1]
      local e = A[expr.kind](self:register(scope, l), self:register(scope, r))
      self:addStatement(self:setRegister(scope, regs[i], e), {regs[i]}, {l, r}, true)
      self:freeRegister(r, false)
      self:freeRegister(l, false)
    else
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
