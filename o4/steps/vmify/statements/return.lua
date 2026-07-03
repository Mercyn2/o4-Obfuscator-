local A  = require "ast"
local AK = A.AstKind
return function(self, stmt, funcDepth)
  local scope   = self.activeBlock.scope
  local entries = {}
  local regs    = {}
  for i, expr in ipairs(stmt.args) do
    if i == #stmt.args and (expr.kind == AK.FunctionCallExpression or expr.kind == AK.PassSelfFunctionCallExpression or expr.kind == AK.VarargExpression) then
      local r = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1]
      entries[#entries+1] = A.TableEntry(A.FunctionCallExpression(self:unpack(scope), { self:register(scope, r) }))
      regs[#regs+1] = r
    else
      local r = self:compileExpression(expr, funcDepth, 1)[1]
      entries[#entries+1] = A.TableEntry(self:register(scope, r))
      regs[#regs+1] = r
    end
  end
  for _, r in ipairs(regs) do self:freeRegister(r, false) end
  self:addStatement(self:setReturn(scope, A.TableConstructorExpression(entries)), {self.RETURN_REGISTER}, regs, false)
  self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false)
  self.activeBlock.advanceToNextBlock = false
end
