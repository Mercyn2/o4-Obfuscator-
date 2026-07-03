local A  = require "ast"
local S  = require "scope"
local U  = require "util"
local AK = A.AstKind

local unpack = unpack or table.unpack

local Block         = require "steps.vmify.block"
local registerMod   = require "steps.vmify.register"
local upvalueMod    = require "steps.vmify.upvalue"
local emitMod       = require "steps.vmify.emit"
local compileTopMod = require "steps.vmify.compile_top"
local stmtHandlers  = require "steps.vmify.statements"
local exprHandlers  = require "steps.vmify.expressions"

local Compiler = {}
Compiler.__index = Compiler

function Compiler:new()
  local c = setmetatable({}, self)
  -- sentinels (unique table refs instead of newproxy)
  c.VAR_REGISTER    = {}
  c.RETURN_ALL      = {}
  c.POS_REGISTER    = {}
  c.RETURN_REGISTER = {}
  c.BIN_OPS = U.lookupify{
    AK.LessThanExpression, AK.GreaterThanExpression,
    AK.LessThanOrEqualsExpression, AK.GreaterThanOrEqualsExpression,
    AK.NotEqualsExpression, AK.EqualsExpression,
    AK.StrCatExpression, AK.AddExpression, AK.SubExpression,
    AK.MulExpression, AK.DivExpression, AK.ModExpression, AK.PowExpression,
  }
  return c
end

registerMod(Compiler)
upvalueMod(Compiler)
emitMod(Compiler)
compileTopMod(Compiler)

-- internal block helpers
function Compiler:_createBlock()
  local b = self.blockMgr:newBlock()
  self.blocks[#self.blocks+1] = b
  return b
end
function Compiler:_setActiveBlock(b) self.activeBlock = b end

function Compiler:addStatement(stmt, writes, reads, usesUpvals)
  if self.activeBlock.advanceToNextBlock then
    local lk = U.lookupify
    self.activeBlock.statements[#self.activeBlock.statements+1] = {
      statement  = stmt,
      writes     = lk(writes or {}),
      reads      = lk(reads  or {}),
      usesUpvals = usesUpvals or false,
    }
  end
end

function Compiler:compileStatement(stmt, funcDepth)
  local h = stmtHandlers[stmt.kind]
  if h then h(self, stmt, funcDepth); return end
  require("logger"):error("Uncompilable statement: " .. tostring(stmt.kind))
end

function Compiler:compileExpression(expr, funcDepth, numReturns)
  local h = exprHandlers[expr.kind]
  if h then return h(self, expr, funcDepth, numReturns) end
  require("logger"):error("Uncompilable expression: " .. tostring(expr.kind))
end

-- createClosure factory vars (by argcount)
function Compiler:getCreateClosureVar(argCount)
  if not self.createClosureVars[argCount] then
    local csc     = S:new(self.scope)
    local posArg  = csc:addVariable()
    local uvsArg  = csc:addVariable()
    local subSc   = S:new(csc)
    subSc:addReferenceToHigherScope(self.scope, self.containerFuncVar)
    subSc:addReferenceToHigherScope(csc, posArg)
    subSc:addReferenceToHigherScope(csc, uvsArg, 1)

    local argVars, argEntries = {}, {}
    for i = 1, argCount do
      local av = subSc:addVariable()
      argVars[i]   = A.VariableExpression(subSc, av)
      argEntries[i]= A.TableEntry(A.VariableExpression(subSc, av))
    end

    local funcVar = csc:addVariable()
    local val = A.FunctionLiteralExpression(
      { A.VariableExpression(csc, posArg), A.VariableExpression(csc, uvsArg) },
      A.Block({
        A.LocalVariableDeclaration(csc, {funcVar}, {
          A.FunctionLiteralExpression(argVars, A.Block({
            A.ReturnStatement({
              A.FunctionCallExpression(A.VariableExpression(self.scope, self.containerFuncVar), {
                A.VariableExpression(csc, posArg),
                A.TableConstructorExpression(argEntries),
                A.VariableExpression(csc, uvsArg),
              })
            })
          }, subSc))
        }),
        A.ReturnStatement({ A.VariableExpression(csc, funcVar) }),
      }, csc)
    )
    local varId = self.scope:addVariable()
    self.createClosureVars[argCount] = {
      scope = self.scope, id = varId, val = val
    }
  end
  local e = self.createClosureVars[argCount]
  return e.scope, e.id
end

function Compiler:compile(ast)
  -- reset state
  self.blocks              = {}
  self.registers           = {}
  self.activeBlock         = nil
  self.registersForVar     = {}
  self.scopeFunctionDepths = {}
  self.maxUsedRegister     = 0
  self.usedRegisters       = 0
  self.registerVars        = {}
  self.usedBlockIds        = {}
  self.upvalVars           = {}
  self.registerUsageStack  = {}
  self.createClosureVars   = {}

  -- global scope
  local newGlobal = S:newGlobal()
  local _, getfenvVar    = newGlobal:resolve("getfenv")
  local _, tableVar      = newGlobal:resolve("table")
  local _, unpackGVar    = newGlobal:resolve("unpack")
  local _, envGVar       = newGlobal:resolve("_ENV")
  local _, setmetaVar    = newGlobal:resolve("setmetatable")

  local psc = S:new(newGlobal)
  psc:addReferenceToHigherScope(newGlobal, getfenvVar, 2)
  psc:addReferenceToHigherScope(newGlobal, tableVar)
  psc:addReferenceToHigherScope(newGlobal, unpackGVar)
  psc:addReferenceToHigherScope(newGlobal, envGVar)

  self.scope = S:new(psc)

  -- VM-level vars in scope
  self.envVar            = self.scope:addVariable()
  self.unpackVar         = self.scope:addVariable()
  self.containerFuncVar  = self.scope:addVariable()
  self.upvalsTableVar    = self.scope:addVariable()
  self.upvalsRefsVar     = self.scope:addVariable()
  self.allocUpvalVar     = self.scope:addVariable()
  self.freeUpvalVar      = self.scope:addVariable()
  self.currentUpvalIdVar = self.scope:addVariable()
  self.createVarargClosureVar = self.scope:addVariable()

  local argVar = self.scope:addVariable()

  -- containerFuncScope
  self.containerFuncScope = S:new(self.scope)
  self.posVar             = self.containerFuncScope:addVariable()
  self.argsVar            = self.containerFuncScope:addVariable()
  self.currentUpvaluesVar = self.containerFuncScope:addVariable()
  self.returnVar          = self.containerFuncScope:addVariable()

  -- block manager
  self.blockMgr = Block.create(self.containerFuncScope)

  -- top-level upvalue allocation
  local upvalEntries = {}
  local upvalIds     = {}
  self.getUpvalueId  = function(self2, scope, id)
    if upvalIds[id] then return upvalIds[id] end
    self2.scope:addReferenceToHigherScope(self2.scope, self2.allocUpvalVar)
    local expr = A.FunctionCallExpression(A.VariableExpression(self2.scope, self2.allocUpvalVar), {})
    upvalEntries[#upvalEntries+1] = A.TableEntry(expr)
    local uid = #upvalEntries
    upvalIds[id] = uid
    return uid
  end

  -- compile the AST
  self:compileTopNode(ast)

  -- build vararg createClosure
  local cvsc  = S:new(self.scope)
  local cvPos = cvsc:addVariable()
  local cvUvs = cvsc:addVariable()
  local cvSub = S:new(cvsc)
  cvSub:addReferenceToHigherScope(self.scope, self.containerFuncVar)
  cvSub:addReferenceToHigherScope(cvsc, cvPos)
  cvSub:addReferenceToHigherScope(cvsc, cvUvs, 1)

  local cvFuncVar = cvsc:addVariable()
  local createVarargVal = A.FunctionLiteralExpression(
    { A.VariableExpression(cvsc, cvPos), A.VariableExpression(cvsc, cvUvs) },
    A.Block({
      A.LocalVariableDeclaration(cvsc, {cvFuncVar}, {
        A.FunctionLiteralExpression({ A.VarargExpression() }, A.Block({
          A.ReturnStatement({
            A.FunctionCallExpression(A.VariableExpression(self.scope, self.containerFuncVar), {
              A.VariableExpression(cvsc, cvPos),
              A.TableConstructorExpression({ A.TableEntry(A.VarargExpression()) }),
              A.VariableExpression(cvsc, cvUvs),
            })
          })
        }, cvSub))
      }),
      A.ReturnStatement({ A.VariableExpression(cvsc, cvFuncVar) }),
    }, cvsc)
  )

  -- build containerFunc
  local containerFuncVal = A.FunctionLiteralExpression(
    {
      A.VariableExpression(self.containerFuncScope, self.posVar),
      A.VariableExpression(self.containerFuncScope, self.argsVar),
      A.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
    },
    self:emitContainerFuncBody()
  )

  -- all VM var assignments (shuffled)
  local assignments = {
    { var = A.AssignmentVariable(self.scope, self.containerFuncVar),  val = containerFuncVal },
    { var = A.AssignmentVariable(self.scope, self.createVarargClosureVar), val = createVarargVal },
    { var = A.AssignmentVariable(self.scope, self.upvalsTableVar),    val = A.TableConstructorExpression({}) },
    { var = A.AssignmentVariable(self.scope, self.upvalsRefsVar),     val = A.TableConstructorExpression({}) },
    { var = A.AssignmentVariable(self.scope, self.currentUpvalIdVar), val = A.NumberExpression(0) },
    { var = A.AssignmentVariable(self.scope, self.allocUpvalVar),     val = self:createAllocUpvalFunction() },
    { var = A.AssignmentVariable(self.scope, self.freeUpvalVar),      val = self:createFreeUpvalFunction() },
  }
  for _, e in pairs(self.createClosureVars) do
    assignments[#assignments+1] = { var = A.AssignmentVariable(self.scope, e.id), val = e.val }
  end

  U.shuffle(assignments)
  local lhs, rhs = {}, {}
  for _, a in ipairs(assignments) do lhs[#lhs+1] = a.var; rhs[#rhs+1] = a.val end

  -- entry call: createVarargClosure(startId, {})(unpack(args))
  local entrySc = S:new(self.scope)
  entrySc:addReferenceToHigherScope(self.scope, self.createVarargClosureVar)
  entrySc:addReferenceToHigherScope(self.scope, self.unpackVar)
  entrySc:addReferenceToHigherScope(self.scope, argVar)

  local entryCall = A.FunctionCallExpression(
    A.FunctionCallExpression(
      A.VariableExpression(self.scope, self.createVarargClosureVar),
      { A.NumberExpression(self.startBlockId), A.TableConstructorExpression(upvalEntries) }
    ),
    { A.FunctionCallExpression(A.VariableExpression(self.scope, self.unpackVar), {
        A.VariableExpression(self.scope, argVar)
      })
    }
  )

  -- outer wrapper function
  local wrapperBody = A.Block({
    A.AssignmentStatement(lhs, rhs),
    A.ReturnStatement({ entryCall }),
  }, self.scope)

  local wrapperArgs = {
    A.VariableExpression(self.scope, self.envVar),
    A.VariableExpression(self.scope, self.unpackVar),
    A.VariableExpression(self.scope, argVar),
  }

  local wrapperFunc = A.FunctionLiteralExpression(wrapperArgs, wrapperBody)

  -- call args: env, unpack, args table
  local callArgs = {
    A.OrExpression(
      A.AndExpression(
        A.VariableExpression(newGlobal, getfenvVar),
        A.FunctionCallExpression(A.VariableExpression(newGlobal, getfenvVar), {})
      ),
      A.VariableExpression(newGlobal, envGVar)
    ),
    A.OrExpression(
      A.VariableExpression(newGlobal, unpackGVar),
      A.IndexExpression(A.VariableExpression(newGlobal, tableVar), A.StringExpression("unpack"))
    ),
    A.TableConstructorExpression({ A.TableEntry(A.VarargExpression()) }),
  }

  return A.TopNode(
    A.Block({
      A.ReturnStatement({ A.FunctionCallExpression(wrapperFunc, callArgs) })
    }, psc),
    newGlobal
  )
end

return Compiler
