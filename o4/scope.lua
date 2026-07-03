local config=require"config"
local S={}
local sI=0
local nI=1
S.__index=S
function S:new(p,name)sI=sI+1;local s={isGlobal=false,parentScope=p,variables={},variablesLookup={},referenceCounts={},variablesFromHigherScopes={},skipIdLookup={},name=name or("scope_"..sI),children={},level=p.level and(p.level+1)or 1};setmetatable(s,self);p:addChild(s);return s end
function S:newGlobal()local s={isGlobal=true,parentScope=nil,variables={},variablesLookup={},referenceCounts={},skipIdLookup={},name="global_scope",children={},level=0};setmetatable(s,self);return s end
function S:getParent()return self.parentScope end
function S:setParent(p)self.parentScope:removeChild(self);p:addChild(self);self.parentScope=p;self.level=p.level+1 end
function S:addVariable(name)if not name then name=string.format("%s%i",config.IdentPrefix,nI);nI=nI+1 end;table.insert(self.variables,name);local id=#self.variables;self.variablesLookup[name]=id;return id end
function S:addDisabledVariable(name)if not name then name=string.format("%s%i",config.IdentPrefix,nI);nI=nI+1 end;table.insert(self.variables,name);return#self.variables end
function S:enableVariable(id)local name=self.variables[id];self.variablesLookup[name]=id end
function S:addIfNotExists(id)if not self.variables[id] then local name=string.format("%s%i",config.IdentPrefix,nI);nI=nI+1;self.variables[id]=name;self.variablesLookup[name]=id end;return id end
function S:hasVariable(name)if self.isGlobal then if self.variablesLookup[name]==nil then self:addVariable(name)end;return true end;return self.variablesLookup[name]~=nil end
function S:getVariables()return self.variables end
function S:getMaxId()return#self.variables end
function S:getVariableName(id)return self.variables[id]end
function S:removeVariable(id)local name=self.variables[id];self.variables[id]=nil;self.variablesLookup[name]=nil;self.skipIdLookup[id]=true end
function S:resetReferences(id)self.referenceCounts[id]=0 end
function S:getReferences(id)return self.referenceCounts[id]or 0 end
function S:addReference(id)if id==nil then print("NIL ID! traceback:") print(debug.traceback()) end self.referenceCounts[id]=(self.referenceCounts[id]or 0)+1 end
function S:removeReference(id)self.referenceCounts[id]=(self.referenceCounts[id]or 0)-1 end
function S:resolve(name)if self:hasVariable(name)then return self,self.variablesLookup[name]end;assert(self.parentScope);local sc,id=self.parentScope:resolve(name);self:addReferenceToHigherScope(sc,id,nil,true);return sc,id end
function S:resolveGlobal(name)if self.isGlobal and self:hasVariable(name)then return self,self.variablesLookup[name]end;assert(self.parentScope);local sc,id=self.parentScope:resolveGlobal(name);self:addReferenceToHigherScope(sc,id,nil,true);return sc,id end
function S:clearReferences()self.referenceCounts={};self.variablesFromHigherScopes={} end
function S:addChild(child)for sc,ids in pairs(child.variablesFromHigherScopes)do for id,cnt in pairs(ids)do if cnt and cnt>0 then self:addReferenceToHigherScope(sc,id,cnt)end end end;table.insert(self.children,child)end
function S:removeChild(child)for i,v in ipairs(self.children)do if v==child then for sc,ids in pairs(v.variablesFromHigherScopes)do for id,cnt in pairs(ids)do if cnt and cnt>0 then self:removeReferenceToHigherScope(sc,id,cnt)end end end;return table.remove(self.children,i)end end end
function S:addReferenceToHigherScope(sc,id,n,b)n=n or 1;if self.isGlobal then return end;if sc==self then self.referenceCounts[id]=(self.referenceCounts[id]or 0)+n;return end;if not self.variablesFromHigherScopes[sc]then self.variablesFromHigherScopes[sc]={}end;local sr=self.variablesFromHigherScopes[sc];sr[id]=(sr[id]or 0)+n;if not b then self.parentScope:addReferenceToHigherScope(sc,id,n)end end
function S:removeReferenceToHigherScope(sc,id,n,b)n=n or 1;if self.isGlobal then return end;if sc==self then self.referenceCounts[id]=(self.referenceCounts[id]or 0)-n;return end;if not self.variablesFromHigherScopes[sc]then self.variablesFromHigherScopes[sc]={}end;local sr=self.variablesFromHigherScopes[sc];sr[id]=(sr[id]or 0)-n;if not b then self.parentScope:removeReferenceToHigherScope(sc,id,n)end end
function S:renameVariables(settings)if not self.isGlobal then local prefix=settings.prefix or"";local forbidden={};for _,kw in pairs(settings.Keywords)do forbidden[kw]=true end;for sc,ids in pairs(self.variablesFromHigherScopes)do for id,cnt in pairs(ids)do if cnt and cnt>0 then local n=sc:getVariableName(id);forbidden[n]=true end end end;self.variablesLookup={};local i=0;for id,origName in pairs(self.variables)do if not self.skipIdLookup[id]and(self.referenceCounts[id]or 0)>=0 then local name;repeat name=prefix..settings.generateName(i,self,origName);if name==nil then name=origName end;i=i+1 until not forbidden[name];self.variables[id]=name;self.variablesLookup[name]=id end end end;for _,child in pairs(self.children)do child:renameVariables(settings)end end
return S
