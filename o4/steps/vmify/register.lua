local A   = require "ast"
local MAX_REGS = 100

return function(Compiler)
  Compiler.MAX_REGS = MAX_REGS

  function Compiler:freeRegister(id, force)
    if force or not (self.registers[id] == self.VAR_REGISTER) then
      self.usedRegisters = self.usedRegisters - 1
      self.registers[id] = false
    end
  end

  function Compiler:isVarRegister(id)
    return self.registers[id] == self.VAR_REGISTER
  end

  function Compiler:allocRegister(isVar)
    self.usedRegisters = self.usedRegisters + 1
    if not isVar then
      if not self.registers[self.POS_REGISTER] then
        self.registers[self.POS_REGISTER] = true
        return self.POS_REGISTER
      end
      if not self.registers[self.RETURN_REGISTER] then
        self.registers[self.RETURN_REGISTER] = true
        return self.RETURN_REGISTER
      end
    end
    local id = 0
    repeat id = id + 1 until not self.registers[id]
    if id > self.maxUsedRegister then self.maxUsedRegister = id end
    self.registers[id] = isVar and self.VAR_REGISTER or true
    return id
  end

  function Compiler:isUpvalue(scope, id)
    return self.upvalVars[scope] and self.upvalVars[scope][id]
  end

  function Compiler:makeUpvalue(scope, id)
    if not self.upvalVars[scope] then self.upvalVars[scope] = {} end
    self.upvalVars[scope][id] = true
  end

  function Compiler:getVarRegister(scope, id, funcDepth, potentialId)
    if not self.registersForVar[scope] then
      self.registersForVar[scope] = {}
      self.scopeFunctionDepths[scope] = funcDepth
    end
    local reg = self.registersForVar[scope][id]
    if not reg then
      if potentialId
        and self.registers[potentialId] ~= self.VAR_REGISTER
        and potentialId ~= self.POS_REGISTER
        and potentialId ~= self.RETURN_REGISTER
      then
        self.registers[potentialId] = self.VAR_REGISTER
        reg = potentialId
      else
        reg = self:allocRegister(true)
      end
      self.registersForVar[scope][id] = reg
    end
    return reg
  end

  function Compiler:getRegisterVarId(id)
    local varId = self.registerVars[id]
    if not varId then
      varId = self.containerFuncScope:addVariable()
      self.registerVars[id] = varId
    end
    return varId
  end

  function Compiler:register(scope, id)
    if id == self.POS_REGISTER    then return self:pos(scope) end
    if id == self.RETURN_REGISTER then return self:getReturn(scope) end
    if id < MAX_REGS then
      local vid = self:getRegisterVarId(id)
      scope:addReferenceToHigherScope(self.containerFuncScope, vid)
      return A.VariableExpression(self.containerFuncScope, vid)
    end
    local vid = self:getRegisterVarId(MAX_REGS)
    scope:addReferenceToHigherScope(self.containerFuncScope, vid)
    return A.IndexExpression(
      A.VariableExpression(self.containerFuncScope, vid),
      A.NumberExpression((id - MAX_REGS) + 1)
    )
  end

  function Compiler:registerAssignment(scope, id)
    if id == self.POS_REGISTER    then return self:posAssignment(scope) end
    if id == self.RETURN_REGISTER then return self:returnAssignment(scope) end
    if id < MAX_REGS then
      local vid = self:getRegisterVarId(id)
      scope:addReferenceToHigherScope(self.containerFuncScope, vid)
      return A.AssignmentVariable(self.containerFuncScope, vid)
    end
    local vid = self:getRegisterVarId(MAX_REGS)
    scope:addReferenceToHigherScope(self.containerFuncScope, vid)
    return A.AssignmentIndexing(
      A.VariableExpression(self.containerFuncScope, vid),
      A.NumberExpression((id - MAX_REGS) + 1)
    )
  end

  function Compiler:setRegister(scope, id, val, compoundArg)
    if compoundArg then
      return compoundArg(self:registerAssignment(scope, id), val)
    end
    return A.AssignmentStatement({ self:registerAssignment(scope, id) }, { val })
  end

  function Compiler:setRegisters(scope, ids, vals)
    local lhs = {}
    for _, id in ipairs(ids) do lhs[#lhs+1] = self:registerAssignment(scope, id) end
    return A.AssignmentStatement(lhs, vals)
  end

  function Compiler:copyRegisters(scope, to, from)
    local lhs, rhs = {}, {}
    for i, id in ipairs(to) do
      local fid = from[i]
      if fid ~= id then
        lhs[#lhs+1] = self:registerAssignment(scope, id)
        rhs[#rhs+1] = self:register(scope, fid)
      end
    end
    if #lhs > 0 then return A.AssignmentStatement(lhs, rhs) end
  end

  function Compiler:resetRegisters()
    self.registers = {}
  end

  function Compiler:pushRegisterUsageInfo()
    table.insert(self.registerUsageStack, {
      usedRegisters = self.usedRegisters,
      registers     = self.registers,
    })
    self.usedRegisters = 0
    self.registers     = {}
  end

  function Compiler:popRegisterUsageInfo()
    local info = table.remove(self.registerUsageStack)
    self.usedRegisters = info.usedRegisters
    self.registers     = info.registers
  end

  -- pos / return helpers
  function Compiler:pos(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar)
    return A.VariableExpression(self.containerFuncScope, self.posVar)
  end
  function Compiler:posAssignment(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar)
    return A.AssignmentVariable(self.containerFuncScope, self.posVar)
  end
  function Compiler:jmp(scope, to)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar)
    return A.AssignmentStatement(
      { A.AssignmentVariable(self.containerFuncScope, self.posVar) }, { to }
    )
  end
  function Compiler:setPos(scope, val)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar)
    local rhs
    if val then
      rhs = A.NumberExpression(val)
    else
      -- obfuscated nil: env["randomKey"] evaluates to nil
      local key = self:_randomKey()
      scope:addReferenceToHigherScope(self.scope, self.envVar)
      rhs = A.IndexExpression(A.VariableExpression(self.scope, self.envVar), A.StringExpression(key))
    end
    return A.AssignmentStatement(
      { A.AssignmentVariable(self.containerFuncScope, self.posVar) }, { rhs }
    )
  end
  function Compiler:setReturn(scope, val)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar)
    return A.AssignmentStatement(
      { A.AssignmentVariable(self.containerFuncScope, self.returnVar) }, { val }
    )
  end
  function Compiler:getReturn(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar)
    return A.VariableExpression(self.containerFuncScope, self.returnVar)
  end
  function Compiler:returnAssignment(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar)
    return A.AssignmentVariable(self.containerFuncScope, self.returnVar)
  end
  function Compiler:env(scope)
    scope:addReferenceToHigherScope(self.scope, self.envVar)
    return A.VariableExpression(self.scope, self.envVar)
  end
  function Compiler:unpack(scope)
    scope:addReferenceToHigherScope(self.scope, self.unpackVar)
    return A.VariableExpression(self.scope, self.unpackVar)
  end
  function Compiler:setUpvalueMember(scope, idExpr, valExpr, compoundCtor)
    scope:addReferenceToHigherScope(self.scope, self.upvalsTableVar)
    if compoundCtor then
      return compoundCtor(
        A.AssignmentIndexing(A.VariableExpression(self.scope, self.upvalsTableVar), idExpr),
        valExpr
      )
    end
    return A.AssignmentStatement(
      { A.AssignmentIndexing(A.VariableExpression(self.scope, self.upvalsTableVar), idExpr) },
      { valExpr }
    )
  end
  function Compiler:getUpvalueMember(scope, idExpr)
    scope:addReferenceToHigherScope(self.scope, self.upvalsTableVar)
    return A.IndexExpression(A.VariableExpression(self.scope, self.upvalsTableVar), idExpr)
  end

  -- random key helper
  local _chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  function Compiler:_randomKey()
    local len = math.random(12, 16)
    local s = ""
    for _ = 1, len do
      local i = math.random(1, #_chars)
      s = s .. _chars:sub(i, i)
    end
    return s
  end
end
