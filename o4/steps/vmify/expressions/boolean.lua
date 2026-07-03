local A  = require "ast"
local AK = A.AstKind

local evals = {
  [A.GreaterThanExpression]        = function(a,b) return a > b  end,
  [A.LessThanExpression]           = function(a,b) return a < b  end,
  [A.GreaterThanOrEqualsExpression]= function(a,b) return a >= b end,
  [A.LessThanOrEqualsExpression]   = function(a,b) return a <= b end,
  [A.NotEqualsExpression]          = function(a,b) return a ~= b end,
}
local keys = { A.GreaterThanExpression, A.LessThanExpression,
               A.GreaterThanOrEqualsExpression, A.LessThanOrEqualsExpression,
               A.NotEqualsExpression }

local function fakeCondition(want)
  local fn, l, r, result
  repeat
    fn = keys[math.random(1, #keys)]
    l  = math.random(1, 2^24)
    r  = math.random(1, 2^24)
    result = evals[fn](l, r)
  until result == want
  return fn(A.NumberExpression(l), A.NumberExpression(r))
end

return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i == 1 then
      self:addStatement(self:setRegister(scope, regs[i], fakeCondition(expr.value)), {regs[i]}, {}, false)
    else
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
