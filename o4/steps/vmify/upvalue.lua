-- No newproxy. Simple refcount-based upvalue table.
local A = require "ast"
local S = require "scope"

return function(Compiler)

  function Compiler:createAllocUpvalFunction()
    local sc = S:new(self.scope)
    sc:addReferenceToHigherScope(self.scope, self.currentUpvalIdVar, 4)
    sc:addReferenceToHigherScope(self.scope, self.upvalsRefsVar, 1)
    return A.FunctionLiteralExpression({}, A.Block({
      A.AssignmentStatement(
        { A.AssignmentVariable(self.scope, self.currentUpvalIdVar) },
        { A.AddExpression(
            A.VariableExpression(self.scope, self.currentUpvalIdVar),
            A.NumberExpression(1)
          ) }
      ),
      A.AssignmentStatement(
        { A.AssignmentIndexing(
            A.VariableExpression(self.scope, self.upvalsRefsVar),
            A.VariableExpression(self.scope, self.currentUpvalIdVar)
          ) },
        { A.NumberExpression(1) }
      ),
      A.ReturnStatement({ A.VariableExpression(self.scope, self.currentUpvalIdVar) }),
    }, sc))
  end

  function Compiler:createFreeUpvalFunction()
    local sc  = S:new(self.scope)
    local arg = sc:addVariable()
    local isc = S:new(sc)
    isc:addReferenceToHigherScope(self.scope, self.upvalsRefsVar, 1)
    isc:addReferenceToHigherScope(self.scope, self.upvalsTableVar, 1)
    isc:addReferenceToHigherScope(sc, arg, 3)
    sc:addReferenceToHigherScope(self.scope, self.upvalsRefsVar, 2)
    return A.FunctionLiteralExpression(
      { A.VariableExpression(sc, arg) },
      A.Block({
        A.AssignmentStatement(
          { A.AssignmentIndexing(
              A.VariableExpression(self.scope, self.upvalsRefsVar),
              A.VariableExpression(sc, arg)
            ) },
          { A.SubExpression(
              A.IndexExpression(
                A.VariableExpression(self.scope, self.upvalsRefsVar),
                A.VariableExpression(sc, arg)
              ),
              A.NumberExpression(1)
            ) }
        ),
        A.IfStatement(
          A.EqualsExpression(
            A.IndexExpression(
              A.VariableExpression(self.scope, self.upvalsRefsVar),
              A.VariableExpression(sc, arg)
            ),
            A.NumberExpression(0)
          ),
          A.Block({
            A.AssignmentStatement(
              {
                A.AssignmentIndexing(A.VariableExpression(self.scope, self.upvalsRefsVar), A.VariableExpression(sc, arg)),
                A.AssignmentIndexing(A.VariableExpression(self.scope, self.upvalsTableVar), A.VariableExpression(sc, arg)),
              },
              { A.NilExpression(), A.NilExpression() }
            ),
          }, isc),
          {}, nil
        ),
      }, sc)
    )
  end

end
