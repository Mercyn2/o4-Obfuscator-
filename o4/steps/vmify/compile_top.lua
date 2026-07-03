local A  = require "ast"
local S  = require "scope"
local U  = require "util"
local V  = require "visit"
local AK = require("ast").AstKind

return function(Compiler)

  function Compiler:compileTopNode(node)
    local startBlock = self:_createBlock()
    self.startBlockId = startBlock.id
    self:_setActiveBlock(startBlock)

    -- upvalue detection pass
    local varAccessSet = U.lookupify{
      AK.AssignmentVariable, AK.VariableExpression,
      AK.FunctionDeclaration, AK.LocalFunctionDeclaration,
    }
    V.visitAst(node, function(n, data)
      if n.kind == AK.Block then
        n.scope.__funcDepth = data.functionData.depth
      end
      if varAccessSet[n.kind] then
        if not n.scope.isGlobal then
          local dd = n.scope.__funcDepth
          local ad = data.functionData.depth
          if dd and dd < ad then
            if not self:isUpvalue(n.scope, n.id) then
              self:makeUpvalue(n.scope, n.id)
            end
          end
        end
      end
    end, nil, {})

    -- vararg register (captures ...)
    self.varargReg = self:allocRegister(true)
    local scope    = startBlock.scope
    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
    scope:addReferenceToHigherScope(self.scope, self.unpackVar)
    self:addStatement(
      self:setRegister(scope, self.varargReg,
        A.TableConstructorExpression({
          A.TableEntry(A.FunctionCallExpression(self:unpack(scope), {
            A.VariableExpression(self.containerFuncScope, self.argsVar)
          }))
        })
      ), {self.varargReg}, {}, false
    )

    self:compileBlock(node.body, 0)

    if self.activeBlock.advanceToNextBlock then
      self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false)
      self:addStatement(self:setReturn(self.activeBlock.scope, A.TableConstructorExpression({})), {self.RETURN_REGISTER}, {}, false)
      self.activeBlock.advanceToNextBlock = false
    end

    self:resetRegisters()
  end

  function Compiler:compileFunction(node, funcDepth)
    funcDepth = funcDepth + 1

    local oldActiveBlock    = self.activeBlock
    local upperVarargReg    = self.varargReg
    self.varargReg          = nil

    local upvalExprs = {}
    local upvalIds   = {}
    local usedRegs   = {}

    local oldGetUpvalueId   = self.getUpvalueId
    self.getUpvalueId = function(self2, scope, id)
      if not upvalIds[scope] then upvalIds[scope] = {} end
      if upvalIds[scope][id] then return upvalIds[scope][id] end

      local sfd  = self2.scopeFunctionDepths[scope]
      local expr
      if sfd == funcDepth then
        -- same function level → allocate new upvalue slot
        oldActiveBlock.scope:addReferenceToHigherScope(self2.scope, self2.allocUpvalVar)
        expr = A.FunctionCallExpression(A.VariableExpression(self2.scope, self2.allocUpvalVar), {})
      elseif sfd == funcDepth - 1 then
        -- one level up → capture the register
        local varReg = self2:getVarRegister(scope, id, sfd, nil)
        expr = self2:register(oldActiveBlock.scope, varReg)
        usedRegs[#usedRegs+1] = varReg
      else
        -- deeper → thread through currentUpvalues
        local hid = oldGetUpvalueId(self2, scope, id)
        oldActiveBlock.scope:addReferenceToHigherScope(self2.containerFuncScope, self2.currentUpvaluesVar)
        expr = A.IndexExpression(
          A.VariableExpression(self2.containerFuncScope, self2.currentUpvaluesVar),
          A.NumberExpression(hid)
        )
      end

      upvalExprs[#upvalExprs+1] = A.TableEntry(expr)
      local uid = #upvalExprs
      upvalIds[scope][id] = uid
      return uid
    end

    local block = self:_createBlock()
    self:_setActiveBlock(block)
    local scope = block.scope
    self:pushRegisterUsageInfo()

    -- compile args
    for i, arg in ipairs(node.args) do
      if arg.kind == AK.VariableExpression then
        local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil)
        if self:isUpvalue(arg.scope, arg.id) then
          scope:addReferenceToHigherScope(self.scope, self.allocUpvalVar)
          self:addStatement(
            self:setRegister(scope, argReg,
              A.FunctionCallExpression(A.VariableExpression(self.scope, self.allocUpvalVar), {})
            ), {argReg}, {}, false
          )
          scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
          self:addStatement(
            self:setUpvalueMember(scope,
              self:register(scope, argReg),
              A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.argsVar), A.NumberExpression(i))
            ), {}, {argReg}, true
          )
        else
          scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
          self:addStatement(
            self:setRegister(scope, argReg,
              A.IndexExpression(A.VariableExpression(self.containerFuncScope, self.argsVar), A.NumberExpression(i))
            ), {argReg}, {}, false
          )
        end
      else
        -- vararg
        self.varargReg = self:allocRegister(true)
        scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
        scope:addReferenceToHigherScope(self.scope, self.unpackVar)
        self:addStatement(
          self:setRegister(scope, self.varargReg,
            A.TableConstructorExpression({
              A.TableEntry(A.FunctionCallExpression(self:unpack(scope), {
                A.VariableExpression(self.containerFuncScope, self.argsVar),
                A.NumberExpression(#node.args) -- skip named args, rest is vararg
              }))
            })
          ), {self.varargReg}, {}, false
        )
      end
    end

    self:compileBlock(node.body, funcDepth)

    if self.activeBlock.advanceToNextBlock then
      self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false)
      self:addStatement(self:setReturn(self.activeBlock.scope, A.TableConstructorExpression({})), {self.RETURN_REGISTER}, {}, false)
      self.activeBlock.advanceToNextBlock = false
    end

    if self.varargReg then self:freeRegister(self.varargReg, true) end
    self.varargReg    = upperVarargReg
    self.getUpvalueId = oldGetUpvalueId
    self:popRegisterUsageInfo()
    self:_setActiveBlock(oldActiveBlock)

    local retReg    = self:allocRegister(false)
    local outerSc   = oldActiveBlock.scope
    local isVararg  = #node.args > 0 and node.args[#node.args].kind == AK.VarargExpression

    local closureExpr
    if isVararg then
      outerSc:addReferenceToHigherScope(self.scope, self.createVarargClosureVar)
      closureExpr = A.FunctionCallExpression(
        A.VariableExpression(self.scope, self.createVarargClosureVar),
        { A.NumberExpression(block.id), A.TableConstructorExpression(upvalExprs) }
      )
    else
      local csc, cvar = self:getCreateClosureVar(#node.args)
      outerSc:addReferenceToHigherScope(csc, cvar)
      closureExpr = A.FunctionCallExpression(
        A.VariableExpression(csc, cvar),
        { A.NumberExpression(block.id), A.TableConstructorExpression(upvalExprs) }
      )
    end

    self:addStatement(
      self:setRegister(outerSc, retReg, closureExpr),
      {retReg}, usedRegs, false
    )
    return retReg
  end

  function Compiler:compileBlock(block, funcDepth)
    for _, stat in ipairs(block.statements) do
      self:compileStatement(stat, funcDepth)
    end
    local scope = self.activeBlock.scope
    for id in ipairs(block.scope.variables) do
      local varReg = self:getVarRegister(block.scope, id, funcDepth, nil)
      local skipFree = self.noAutoFreeUpval and self.noAutoFreeUpval[block.scope] and self.noAutoFreeUpval[block.scope][id]
      if self:isUpvalue(block.scope, id) and not skipFree then
        scope:addReferenceToHigherScope(self.scope, self.freeUpvalVar)
        self:addStatement(
          self:setRegister(scope, varReg,
            A.FunctionCallExpression(A.VariableExpression(self.scope, self.freeUpvalVar), {
              self:register(scope, varReg)
            })
          ), {varReg}, {varReg}, false
        )
      elseif not skipFree then
        self:addStatement(
          self:setRegister(scope, varReg, A.NilExpression()),
          {varReg}, {}, false
        )
      end
      self:freeRegister(varReg, true)
    end
  end

end
