-- steps/vmify/builder.lua
-- Wraps a function body (or top-level) into a Prometheus-style VM:
--
--   local function __vm(pos, args, upvals)
--     local r0, r1, ...   -- hoisted locals
--     while pos do
--       <dispatch tree>
--     end
--     return unpack(retReg)
--   end
--   return __vm(startId, {...}, {})
--
-- No newproxy. No select. Lua 5.1 safe.

local A        = require "ast"
local S        = require "scope"
local Block    = require "steps.vmify.block"
local Jump     = require "steps.vmify.jump"
local Compiler = require "steps.vmify.compiler"
local Dispatch = require "steps.vmify.dispatch"

local Builder = {}

--[[
  Core VM builder. Takes:
    ast        - the TopNode or a FunctionLiteralExpression body node
    outerScope - the scope that will contain the vm function variable
  Returns the AST with statements replaced.
]]
function Builder.buildBody(bodyStatements, bodyScope, outerScope, globalScope)
  -- 1. Create the vm function scope
  local vmScope  = S:new(outerScope)
  local posVar   = vmScope:addVariable()   -- pos
  local argsVar  = vmScope:addVariable()   -- args  (table of function args / vararg)
  local retVar   = vmScope:addVariable()   -- ret   (return table)

  -- 2. Resolve unpack from global scope (Lua 5.1 safe)
  local _, unpackSc, unpackId
  do
    local gsc = globalScope
    -- add unpack to global scope if not already there (Lua 5.1 has it globally)
    if not gsc:hasVariable("unpack") then
      gsc:addVariable("unpack")
    end
    unpackSc = gsc
    unpackId = gsc.variablesLookup["unpack"]
  end

  -- 3. Build block manager + compiler
  local blockMgr = Block.create(vmScope)
  local compiler = Compiler.new(blockMgr, vmScope, posVar)

  -- make the original body scope a child of vmScope
  bodyScope:setParent(vmScope)

  -- 4. Compile statements into blocks
  local startBlock = blockMgr:newBlock()
  local finalBlock = compiler:compileBlock(bodyStatements, startBlock, nil)

  -- Ensure last block has a nil jump (stops the while)
  local last = finalBlock.stmts[#finalBlock.stmts]
  if not last or not last._isVmJump then
    Block.addStmt(finalBlock, Jump.jmpNil(vmScope, posVar, finalBlock.scope))
  end

  -- 5. Sort blocks and build dispatch tree
  local sorted      = blockMgr:sorted()
  local dispatchBlk = Dispatch.build(sorted, 1, #sorted, vmScope, vmScope, posVar)

  -- 6. Build the while loop:  while pos do <dispatch> end
  --    The condition is just the pos variable (nil stops it)
  local whileStmt = A.WhileStatement(
    dispatchBlk,                              -- body block containing the dispatch tree
    A.VariableExpression(vmScope, posVar),    -- condition: pos
    vmScope
  )

  -- 7. local pos = startBlock.id
  local initPos = A.LocalVariableDeclaration(
    vmScope,
    { posVar },
    { A.NumberExpression(startBlock.id) }
  )

  -- 8. Build the vm function body:
  --    local pos = N
  --    while pos do ... end
  local vmFuncBody = A.Block({ initPos, whileStmt }, vmScope)

  return vmFuncBody, vmScope
end

--[[
  Top-level entry point.
  Wraps ast.body (the top-level chunk) in a VM do..end block.
]]
function Builder.build(ast)
  local globalScope = ast.globalScope
  local outerScope  = S:new(globalScope)

  -- Grab original statements before we touch anything
  local originalStatements = ast.body.statements
  local originalBodyScope  = ast.body.scope

  local vmFuncBody, vmScope = Builder.buildBody(
    originalStatements,
    originalBodyScope,
    outerScope,
    globalScope
  )

  -- Wrap in a do..end so it's scoped cleanly at top level
  local doStmt = A.DoStatement(vmFuncBody)

  -- Replace the ast body in-place
  ast.body.statements = { doStmt }
  ast.body.scope      = outerScope

  return ast
end

return Builder
