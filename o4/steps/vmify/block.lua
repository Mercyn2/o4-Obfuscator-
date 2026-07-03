local S = require "scope"
local Block = {}
Block.__index = Block

function Block.create(funcScope)
  local self = setmetatable({}, Block)
  self._funcScope = funcScope
  self._blocks    = {}
  self._usedIds   = {}
  return self
end

function Block:newId()
  local id
  repeat id = math.random(1, 2^24) until not self._usedIds[id]
  self._usedIds[id] = true
  return id
end

function Block:newBlock()
  local id = self:newId()
  local sc = S:new(self._funcScope)
  local b  = { id=id, statements={}, scope=sc, advanceToNextBlock=true }
  table.insert(self._blocks, b)
  self._blocks[id] = b
  return b
end

function Block:sorted()
  local list = {}
  for _, b in ipairs(self._blocks) do list[#list+1] = b end
  table.sort(list, function(a,b) return a.id < b.id end)
  return list
end

return Block
