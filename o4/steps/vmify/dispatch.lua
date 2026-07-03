-- steps/vmify/dispatch.lua
-- Builds a binary if/elseif/else dispatch tree for the VM body.
-- The while loop condition is just `pos` (truthy check).
-- The tree goes inside the while body.

local A = require "ast"
local S = require "scope"

local Dispatch = {}

-- Randomly pick a comparison style so each obfuscation looks different
local function makeCondition(funcScope, posVar, scope, bound)
  local posExpr = A.VariableExpression(funcScope, posVar)
  local r = math.random(1, 3)
  if r == 1 then
    -- pos <= bound
    scope:addReferenceToHigherScope(funcScope, posVar)
    return A.LessThanOrEqualsExpression(posExpr, A.NumberExpression(bound))
  elseif r == 2 then
    -- pos < bound + 1  (equivalent)
    scope:addReferenceToHigherScope(funcScope, posVar)
    return A.LessThanExpression(posExpr, A.NumberExpression(bound + 1))
  else
    -- bound >= pos
    scope:addReferenceToHigherScope(funcScope, posVar)
    return A.GreaterThanOrEqualsExpression(A.NumberExpression(bound), posExpr)
  end
end

--[[
  Build recursive binary if/elseif/else tree.
  Returns: { ifNode, elseifs, elseBody } to be stitched by builder.
  Actually returns a single IfStatement AST node.
]]
function Dispatch.build(list, l, r, parentScope, funcScope, posVar)
  if r < l then
    local sc = S:new(parentScope)
    return A.Block({}, sc)
  end

  -- Single block: just emit its statements directly in a block
  if l == r then
    local b   = list[l]
    local sc  = S:new(parentScope)
    -- Copy stmts into a fresh block under parentScope
    return A.Block(b.stmts, sc)
  end

  -- Two blocks: simple if/else, no recursion needed
  if l + 1 == r then
    local lb     = list[l]
    local rb     = list[r]
    local bound  = lb.id
    local ifSc   = S:new(parentScope)
    ifSc:addReferenceToHigherScope(funcScope, posVar)
    local cond   = makeCondition(funcScope, posVar, ifSc, bound)
    local lBlock = A.Block(lb.stmts, S:new(ifSc))
    local rBlock = A.Block(rb.stmts, S:new(ifSc))
    return A.Block({
      A.IfStatement(cond, lBlock, {}, rBlock)
    }, ifSc)
  end

  -- More than two: binary split
  local mid    = math.floor((l + r) / 2)
  local bound  = list[mid].id
  local ifSc   = S:new(parentScope)
  ifSc:addReferenceToHigherScope(funcScope, posVar)

  local cond   = makeCondition(funcScope, posVar, ifSc, bound)

  -- Randomly flip left/right branch to vary output
  local lBlock = Dispatch.build(list, l,     mid,   ifSc, funcScope, posVar)
  local rBlock = Dispatch.build(list, mid+1, r,     ifSc, funcScope, posVar)

  if math.random(1, 4) == 1 then
    -- Use flipped condition variant: if NOT left side, do right
    -- (just swap branches and negate conceptually via > instead of <=)
    ifSc:addReferenceToHigherScope(funcScope, posVar)
    local posExpr2 = A.VariableExpression(funcScope, posVar)
    local flipCond = A.GreaterThanExpression(posExpr2, A.NumberExpression(bound))
    return A.Block({
      A.IfStatement(flipCond, rBlock, {}, lBlock)
    }, ifSc)
  end

  return A.Block({
    A.IfStatement(cond, lBlock, {}, rBlock)
  }, ifSc)
end

return Dispatch
