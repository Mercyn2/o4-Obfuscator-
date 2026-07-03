return function(self, stmt, funcDepth)
  self:compileBlock(stmt.body, funcDepth)
end
