local A  = require "ast"
local AK = A.AstKind
return function(self, stmt, funcDepth)
  local scope  = self.activeBlock.scope
  local retReg = self:compileFunction(stmt, funcDepth)

  if #stmt.indices > 0 then
    local tblReg
    if stmt.scope.isGlobal then
      tblReg = self:allocRegister(false)
      self:addStatement(self:setRegister(scope, tblReg, A.StringExpression(stmt.scope:getVariableName(stmt.id))), {tblReg}, {}, false)
      self:addStatement(self:setRegister(scope, tblReg, A.IndexExpression(self:env(scope), self:register(scope, tblReg))), {tblReg}, {tblReg}, true)
    else
      if self.scopeFunctionDepths[stmt.scope] == funcDepth then
        if self:isUpvalue(stmt.scope, stmt.id) then
          tblReg = self:allocRegister(false)
          local reg = self:getVarRegister(stmt.scope, stmt.id, funcDepth)
          self:addStatement(self:setRegister(scope, tblReg, self:getUpvalueMember(scope, self:register(scope, reg))), {tblReg}, {reg}, true)
        else
          tblReg = self:getVarRegister(stmt.scope, stmt.id, funcDepth, retReg)
        end
      else
        tblReg = self:allocRegister(false)
        local uid = self:getUpvalueId(stmt.scope, stmt.id)
        scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
        self:addStatement(self:setRegister(scope, tblReg, self:getUpvalueMember(scope, A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar), A.NumberExpression(uid)))), {tblReg}, {}, true)
      end
    end
    for i = 1, #stmt.indices - 1 do
      local idxReg = self:compileExpression(A.StringExpression(stmt.indices[i]), funcDepth, 1)[1]
      local oldTbl = tblReg
      tblReg = self:allocRegister(false)
      self:addStatement(self:setRegister(scope, tblReg, A.IndexExpression(self:register(scope, oldTbl), self:register(scope, idxReg))), {tblReg}, {oldTbl, idxReg}, false)
      self:freeRegister(oldTbl, false); self:freeRegister(idxReg, false)
    end
    local idxReg = self:compileExpression(A.StringExpression(stmt.indices[#stmt.indices]), funcDepth, 1)[1]
    self:addStatement(A.AssignmentStatement(
      { A.AssignmentIndexing(self:register(scope, tblReg), self:register(scope, idxReg)) },
      { self:register(scope, retReg) }
    ), {}, {tblReg, idxReg, retReg}, true)
    self:freeRegister(idxReg, false); self:freeRegister(tblReg, false); self:freeRegister(retReg, false)
    return
  end

  if stmt.scope.isGlobal then
    local tmp = self:allocRegister(false)
    self:addStatement(self:setRegister(scope, tmp, A.StringExpression(stmt.scope:getVariableName(stmt.id))), {tmp}, {}, false)
    self:addStatement(A.AssignmentStatement({ A.AssignmentIndexing(self:env(scope), self:register(scope, tmp)) }, { self:register(scope, retReg) }), {}, {tmp, retReg}, true)
    self:freeRegister(tmp, false)
  else
    if self.scopeFunctionDepths[stmt.scope] == funcDepth then
      if self:isUpvalue(stmt.scope, stmt.id) then
        local reg = self:getVarRegister(stmt.scope, stmt.id, funcDepth)
        self:addStatement(self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, retReg)), {}, {reg, retReg}, true)
      else
        local reg = self:getVarRegister(stmt.scope, stmt.id, funcDepth, retReg)
        if reg ~= retReg then
          self:addStatement(self:setRegister(scope, reg, self:register(scope, retReg)), {reg}, {retReg}, false)
        end
      end
    else
      local uid = self:getUpvalueId(stmt.scope, stmt.id)
      scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
      self:addStatement(self:setUpvalueMember(scope, A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar), A.NumberExpression(uid)), self:register(scope, retReg)), {}, {retReg}, true)
    end
  end
  self:freeRegister(retReg, false)
end
