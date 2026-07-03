local A  = require "ast"
local AK = A.AstKind
return function(self, stmt, funcDepth)
  local scope  = self.activeBlock.scope
  local exprRegs = {}
  local indexingRegs = {}

  for i, lh in ipairs(stmt.lhs) do
    if lh.kind == AK.AssignmentIndexing then
      indexingRegs[i] = {
        base  = self:compileExpression(lh.base,  funcDepth, 1)[1],
        index = self:compileExpression(lh.index, funcDepth, 1)[1],
      }
    end
  end

  for i, expr in ipairs(stmt.rhs) do
    if i == #stmt.rhs and #stmt.lhs > #stmt.rhs then
      local rs = self:compileExpression(expr, funcDepth, #stmt.lhs - #stmt.rhs + 1)
      for _, r in ipairs(rs) do
        if self:isVarRegister(r) then
          local tmp = self:allocRegister(false)
          self:addStatement(self:copyRegisters(scope, {tmp}, {r}), {tmp}, {r}, false)
          exprRegs[#exprRegs+1] = tmp
        else exprRegs[#exprRegs+1] = r end
      end
    else
      if stmt.lhs[i] or expr.kind == AK.FunctionCallExpression or expr.kind == AK.PassSelfFunctionCallExpression then
        local r = self:compileExpression(expr, funcDepth, 1)[1]
        if self:isVarRegister(r) then
          local tmp = self:allocRegister(false)
          self:addStatement(self:copyRegisters(scope, {tmp}, {r}), {tmp}, {r}, false)
          exprRegs[#exprRegs+1] = tmp
        else exprRegs[#exprRegs+1] = r end
      end
    end
  end

  for i, lh in ipairs(stmt.lhs) do
    if lh.kind == AK.AssignmentVariable then
      if lh.scope.isGlobal then
        local tmp = self:allocRegister(false)
        self:addStatement(self:setRegister(scope, tmp, A.StringExpression(lh.scope:getVariableName(lh.id))), {tmp}, {}, false)
        self:addStatement(A.AssignmentStatement({ A.AssignmentIndexing(self:env(scope), self:register(scope, tmp)) }, { self:register(scope, exprRegs[i]) }), {}, {tmp, exprRegs[i]}, true)
        self:freeRegister(tmp, false)
      else
        if self.scopeFunctionDepths[lh.scope] == funcDepth then
          if self:isUpvalue(lh.scope, lh.id) then
            local reg = self:getVarRegister(lh.scope, lh.id, funcDepth)
            self:addStatement(self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, exprRegs[i])), {}, {reg, exprRegs[i]}, true)
          else
            local reg = self:getVarRegister(lh.scope, lh.id, funcDepth, exprRegs[i])
            if reg ~= exprRegs[i] then
              self:addStatement(self:setRegister(scope, reg, self:register(scope, exprRegs[i])), {reg}, {exprRegs[i]}, false)
            end
          end
        else
          local uid = self:getUpvalueId(lh.scope, lh.id)
          scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
          self:addStatement(self:setUpvalueMember(scope,
            A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar), A.NumberExpression(uid)),
            self:register(scope, exprRegs[i])
          ), {}, {exprRegs[i]}, true)
        end
      end
    elseif lh.kind == AK.AssignmentIndexing then
      local br = indexingRegs[i].base
      local kr = indexingRegs[i].index
      self:addStatement(A.AssignmentStatement(
        { A.AssignmentIndexing(self:register(scope, br), self:register(scope, kr)) },
        { self:register(scope, exprRegs[i]) }
      ), {}, {exprRegs[i], br, kr}, true)
      self:freeRegister(exprRegs[i], false)
      self:freeRegister(br, false)
      self:freeRegister(kr, false)
    end
  end
end
