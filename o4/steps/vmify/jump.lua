-- steps/vmify/jump.lua

local A = require "ast"

local Jump = {}

-- Helper: make a number expression (plain or as math expression for obfuscation)
local function numExpr(id)
  -- Feature 4: obfuscate block IDs as math expressions
  local r = math.random(1, 3)
  if r == 1 then
    -- id = (id + k) - k
    local k = math.random(1, 9999)
    return A.SubExpression(
      A.AddExpression(A.NumberExpression(id + k), A.NumberExpression(k)),
      A.NumberExpression(k * 2)
    )
  elseif r == 2 then
    -- id = id * 1
    local k = math.random(2, 9)
    return A.DivExpression(
      A.MulExpression(A.NumberExpression(id * k), A.NumberExpression(1)),
      A.NumberExpression(k)
    )
  else
    -- plain number
    return A.NumberExpression(id)
  end
end

-- pos = id
function Jump.jmp(funcScope, posVar, scope, id)
  scope:addReferenceToHigherScope(funcScope, posVar)
  return A.AssignmentStatement(
    { A.AssignmentVariable(funcScope, posVar) },
    { numExpr(id) }
  )
end

-- pos = nil
function Jump.jmpNil(funcScope, posVar, scope)
  scope:addReferenceToHigherScope(funcScope, posVar)
  return A.AssignmentStatement(
    { A.AssignmentVariable(funcScope, posVar) },
    { A.NilExpression() }
  )
end

-- pos = cond and trueId or falseId
function Jump.jmpCond(funcScope, posVar, scope, condExpr, trueId, falseId)
  scope:addReferenceToHigherScope(funcScope, posVar)
  return A.AssignmentStatement(
    { A.AssignmentVariable(funcScope, posVar) },
    {
      A.OrExpression(
        A.AndExpression(condExpr, numExpr(trueId)),
        numExpr(falseId)
      )
    }
  )
end

-- Feature 5: fake jump — emits a wrong pos= that gets overwritten by real jump
function Jump.fakeJmp(funcScope, posVar, scope, realId)
  scope:addReferenceToHigherScope(funcScope, posVar)
  -- pick a random fake id that's different from real
  local fakeId = realId + math.random(100, 9999)
  return A.AssignmentStatement(
    { A.AssignmentVariable(funcScope, posVar) },
    { A.NumberExpression(fakeId) }
  )
end

return Jump
