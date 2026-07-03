local A  = require "ast"
local AK = A.AstKind
local ctors = {
  [AK.CompoundAddStatement]    = A.CompoundAddStatement,
  [AK.CompoundSubStatement]    = A.CompoundSubStatement,
  [AK.CompoundMulStatement]    = A.CompoundMulStatement,
  [AK.CompoundDivStatement]    = A.CompoundDivStatement,
  [AK.CompoundModStatement]    = A.CompoundModStatement,
  [AK.CompoundPowStatement]    = A.CompoundPowStatement,
  [AK.CompoundConcatStatement] = A.CompoundConcatStatement,
}
return function(self, stmt, funcDepth)
  local scope = self.activeBlock.scope
  local ctor  = ctors[stmt.kind]
  local lh    = stmt.lhs
  if lh.kind == AK.AssignmentIndexing then
    local br = self:compileExpression(lh.base,  funcDepth, 1)[1]
    local kr = self:compileExpression(lh.index, funcDepth, 1)[1]
    local vr = self:compileExpression(stmt.rhs, funcDepth, 1)[1]
    self:addStatement(ctor(A.AssignmentIndexing(self:register(scope, br), self:register(scope, kr)), self:register(scope, vr)), {}, {br, kr, vr}, true)
    self:freeRegister(br, false); self:freeRegister(kr, false); self:freeRegister(vr, false)
  else
    local vr = self:compileExpression(stmt.rhs, funcDepth, 1)[1]
    if lh.scope.isGlobal then
      local tmp = self:allocRegister(false)
      self:addStatement(self:setRegister(scope, tmp, A.StringExpression(lh.scope:getVariableName(lh.id))), {tmp}, {}, false)
      self:addStatement(ctor(A.AssignmentIndexing(self:env(scope), self:register(scope, tmp)), self:register(scope, vr)), {}, {tmp, vr}, true)
      self:freeRegister(tmp, false); self:freeRegister(vr, false)
    else
      if self.scopeFunctionDepths[lh.scope] == funcDepth then
        if self:isUpvalue(lh.scope, lh.id) then
          local reg = self:getVarRegister(lh.scope, lh.id, funcDepth)
          self:addStatement(self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, vr), ctor), {}, {reg, vr}, true)
        else
          local reg = self:getVarRegister(lh.scope, lh.id, funcDepth, vr)
          if reg ~= vr then
            self:addStatement(self:setRegister(scope, reg, self:register(scope, vr), ctor), {reg}, {vr}, false)
          end
        end
      else
        local uid = self:getUpvalueId(lh.scope, lh.id)
        scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
        self:addStatement(self:setUpvalueMember(scope, A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar), A.NumberExpression(uid)), self:register(scope, vr), ctor), {}, {vr}, true)
      end
      self:freeRegister(vr, false)
    end
  end
end
