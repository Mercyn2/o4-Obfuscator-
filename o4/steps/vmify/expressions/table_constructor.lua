local A  = require "ast"
local AK = A.AstKind
return function(self, expr, funcDepth, n)
  local scope = self.activeBlock.scope
  local regs  = {}
  for i = 1, n do
    regs[i] = self:allocRegister()
    if i == 1 then
      local entries    = {}
      local entryRegs  = {}
      for ei, entry in ipairs(expr.entries) do
        if entry.kind == AK.TableEntry then
          local v = entry.value
          if ei == #expr.entries and (v.kind == AK.FunctionCallExpression or v.kind == AK.PassSelfFunctionCallExpression or v.kind == AK.VarargExpression) then
            local r = self:compileExpression(v, funcDepth, self.RETURN_ALL)[1]
            entries[#entries+1]   = A.TableEntry(A.FunctionCallExpression(self:unpack(scope), { self:register(scope, r) }))
            entryRegs[#entryRegs+1] = r
          else
            local r = self:compileExpression(v, funcDepth, 1)[1]
            entries[#entries+1]   = A.TableEntry(self:register(scope, r))
            entryRegs[#entryRegs+1] = r
          end
        else
          local kr = self:compileExpression(entry.key,   funcDepth, 1)[1]
          local vr = self:compileExpression(entry.value, funcDepth, 1)[1]
          entries[#entries+1] = A.KeyedTableEntry(self:register(scope, kr), self:register(scope, vr))
          entryRegs[#entryRegs+1] = vr
          entryRegs[#entryRegs+1] = kr
        end
      end
      self:addStatement(self:setRegister(scope, regs[i], A.TableConstructorExpression(entries)), {regs[i]}, entryRegs, false)
      for _, r in ipairs(entryRegs) do self:freeRegister(r, false) end
    else
      self:addStatement(self:setRegister(scope, regs[i], A.NilExpression()), {regs[i]}, {}, false)
    end
  end
  return regs
end
