local A  = require "ast"
local S  = require "scope"
local U  = require "util"

return function(Compiler)
  local MAX_REGS = Compiler.MAX_REGS or 100

  local function hasEntries(t)
    return type(t) == "table" and next(t) ~= nil
  end
  local function unionTables(a, b)
    local o = {}
    for k in pairs(a or {}) do o[k] = true end
    for k in pairs(b or {}) do o[k] = true end
    return o
  end

  local function canMerge(sA, sB)
    if not sA or not sB then return false end
    if sA.usesUpvals or sB.usesUpvals then return false end
    local a, b = sA.statement, sB.statement
    if not a or not b then return false end
    if a.kind ~= "AssignmentStatement" or b.kind ~= "AssignmentStatement" then return false end
    if #a.lhs ~= #a.rhs or #b.lhs ~= #b.rhs then return false end
    local function unsafeRhs(rhs)
      for _, e in ipairs(rhs) do
        if type(e) ~= "table" then return true end
        local k = e.kind
        if k == "FunctionCallExpression" or k == "PassSelfFunctionCallExpression" or k == "VarargExpression" then
          return true
        end
      end
      return false
    end
    if unsafeRhs(a.rhs) or unsafeRhs(b.rhs) then return false end
    local aR = sA.reads or {}; local aW = sA.writes or {}
    local bR = sB.reads or {}; local bW = sB.writes or {}
    if not hasEntries(aW) and not hasEntries(bW) then return false end
    for r in pairs(aR) do if bW[r] then return false end end
    for r in pairs(aW) do if bW[r] or bR[r] then return false end end
    return true
  end

  local function mergeTwo(sA, sB)
    local lhs, rhs = {}, {}
    for _, v in ipairs(sA.statement.lhs) do lhs[#lhs+1] = v end
    for _, v in ipairs(sB.statement.lhs) do lhs[#lhs+1] = v end
    for _, v in ipairs(sA.statement.rhs) do rhs[#rhs+1] = v end
    for _, v in ipairs(sB.statement.rhs) do rhs[#rhs+1] = v end
    return {
      statement  = A.AssignmentStatement(lhs, rhs),
      writes     = unionTables(sA.writes, sB.writes),
      reads      = unionTables(sA.reads,  sB.reads),
      usesUpvals = sA.usesUpvals or sB.usesUpvals,
    }
  end

  local function mergePass(list)
    local out = {}
    local i = 1
    while i <= #list do
      local s = list[i]; i = i + 1
      while i <= #list and canMerge(s, list[i]) do
        s = mergeTwo(s, list[i]); i = i + 1
      end
      out[#out+1] = s
    end
    return out
  end

  -- binary dispatch tree
  local function buildDispatch(blocks, l, r, parentScope, funcScope, posVar)
    if r < l then
      return A.Block({}, S:new(parentScope))
    end
    if l == r then
      local b  = blocks[l]
      local sc = S:new(parentScope)
      return A.Block(b.stmts_final, sc)
    end
    local mid    = l + math.ceil((r - l + 1) / 2)
    local bound  = math.floor((blocks[mid-1].id + blocks[mid].id) / 2)
    local ifScope = S:new(parentScope)
    ifScope:addReferenceToHigherScope(funcScope, posVar)
    local lBlock = buildDispatch(blocks, l,   mid-1, ifScope, funcScope, posVar)
    local rBlock = buildDispatch(blocks, mid, r,     ifScope, funcScope, posVar)
    local style  = math.random(1, 3)
    local cond
    local tBlock, fBlock
    if style == 1 then
      cond   = A.LessThanExpression(A.VariableExpression(funcScope, posVar), A.NumberExpression(bound))
      tBlock, fBlock = lBlock, rBlock
    elseif style == 2 then
      cond   = A.GreaterThanExpression(A.NumberExpression(bound), A.VariableExpression(funcScope, posVar))
      tBlock, fBlock = lBlock, rBlock
    else
      cond   = A.GreaterThanExpression(A.VariableExpression(funcScope, posVar), A.NumberExpression(bound))
      tBlock, fBlock = rBlock, lBlock
    end
    return A.Block({
      A.IfStatement(cond, tBlock, {}, fBlock)
    }, ifScope)
  end

  function Compiler:emitContainerFuncBody()
    -- shuffle block order for instruction scrambling
    local shuffled = {}
    for _, b in ipairs(self.blocks) do shuffled[#shuffled+1] = b end
    U.shuffle(shuffled)

    -- instruction reorder + merge within each block
    for _, block in ipairs(shuffled) do
      local bstats = block.statements
      -- bubble-sort style random reorder of independent statements
      for i = 2, #bstats do
        local stat = bstats[i]
        local maxShift = 0
        for shift = 1, i-1 do
          local s2 = bstats[i - shift]
          -- If either statement can have a side effect beyond its tracked
          -- register writes (e.g. `t.field = x` or an upvalue-box write/read),
          -- the read/write register sets alone aren't enough to prove they're
          -- independent -- don't let the scrambler move one past the other.
          if (stat.usesUpvals or s2.usesUpvals) then break end
          local ok = true
          for r in pairs(s2.reads  or {}) do if (stat.writes or {})[r] then ok=false; break end end
          if ok then
            for r in pairs(s2.writes or {}) do
              if (stat.writes or {})[r] or (stat.reads or {})[r] then ok=false; break end
            end
          end
          if not ok then break end
          maxShift = shift
        end
        local shift = math.random(0, maxShift)
        for j = 1, shift do
          bstats[i-j], bstats[i-j+1] = bstats[i-j+1], bstats[i-j]
        end
      end
      -- merge pass (8 rounds)
      local merged = bstats
      for _ = 1, 8 do merged = mergePass(merged) end
      -- extract final statements
      local final = {}
      for _, s in ipairs(merged) do final[#final+1] = s.statement end
      block.stmts_final = final
    end

    -- sort blocks by id for dispatch tree
    local sorted = {}
    for _, b in ipairs(self.blocks) do sorted[#sorted+1] = b end
    table.sort(sorted, function(a, b) return a.id < b.id end)

    local dispatchBody = buildDispatch(
      sorted, 1, #sorted,
      self.containerFuncScope, self.containerFuncScope, self.posVar
    )

    -- declarations
    local decls = { self.returnVar }
    for i, v in pairs(self.registerVars) do
      if i ~= MAX_REGS then decls[#decls+1] = v end
    end

    local stats = {}

    if self.maxUsedRegister >= MAX_REGS then
      stats[#stats+1] = A.LocalVariableDeclaration(
        self.containerFuncScope,
        { self.registerVars[MAX_REGS] },
        { A.TableConstructorExpression({}) }
      )
    end

    stats[#stats+1] = A.LocalVariableDeclaration(
      self.containerFuncScope, U.shuffle(decls), {}
    )
    stats[#stats+1] = A.WhileStatement(
      dispatchBody,
      A.VariableExpression(self.containerFuncScope, self.posVar),
      self.containerFuncScope
    )
    stats[#stats+1] = A.ReturnStatement({
      A.FunctionCallExpression(self:unpack(self.containerFuncScope), {
        A.VariableExpression(self.containerFuncScope, self.returnVar)
      })
    })

    return A.Block(stats, self.containerFuncScope)
  end

end
