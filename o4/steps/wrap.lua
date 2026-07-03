local Step = require "step"
local A = require "ast"
local S = require "scope"

local W = Step:extend()
W.Name = "Wrap in Function"
W.Description = "Wraps entire script in a function call"
W.SettingsDescriptor = {
  Iterations = { name = "Iterations", type = "number", default = 1, min = 1 }
}

function W:init() end

function W:apply(ast)
  for i = 1, self.Iterations do
    local body = ast.body
    local scope = S:new(ast.globalScope)
    body.scope:setParent(scope)
    ast.body = A.Block({
      A.ReturnStatement({
        A.FunctionCallExpression(
          A.FunctionLiteralExpression({ A.VarargExpression() }, body),
          { A.VarargExpression() }
        )
      })
    }, scope)
  end
  return ast
end

return W
