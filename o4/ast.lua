local AK={
  TopNode="TopNode",Block="Block",ContinueStatement="ContinueStatement",BreakStatement="BreakStatement",
  DoStatement="DoStatement",WhileStatement="WhileStatement",ReturnStatement="ReturnStatement",
  RepeatStatement="RepeatStatement",ForInStatement="ForInStatement",ForStatement="ForStatement",
  IfStatement="IfStatement",FunctionDeclaration="FunctionDeclaration",
  LocalFunctionDeclaration="LocalFunctionDeclaration",LocalVariableDeclaration="LocalVariableDeclaration",
  FunctionCallStatement="FunctionCallStatement",PassSelfFunctionCallStatement="PassSelfFunctionCallStatement",
  AssignmentStatement="AssignmentStatement",CompoundAddStatement="CompoundAddStatement",
  CompoundSubStatement="CompoundSubStatement",CompoundMulStatement="CompoundMulStatement",
  CompoundDivStatement="CompoundDivStatement",CompoundModStatement="CompoundModStatement",
  CompoundPowStatement="CompoundPowStatement",CompoundConcatStatement="CompoundConcatStatement",
  AssignmentIndexing="AssignmentIndexing",AssignmentVariable="AssignmentVariable",
  BooleanExpression="BooleanExpression",NumberExpression="NumberExpression",StringExpression="StringExpression",
  NilExpression="NilExpression",VarargExpression="VarargExpression",OrExpression="OrExpression",
  AndExpression="AndExpression",LessThanExpression="LessThanExpression",GreaterThanExpression="GreaterThanExpression",
  LessThanOrEqualsExpression="LessThanOrEqualsExpression",GreaterThanOrEqualsExpression="GreaterThanOrEqualsExpression",
  NotEqualsExpression="NotEqualsExpression",EqualsExpression="EqualsExpression",StrCatExpression="StrCatExpression",
  AddExpression="AddExpression",SubExpression="SubExpression",MulExpression="MulExpression",
  DivExpression="DivExpression",ModExpression="ModExpression",NotExpression="NotExpression",
  LenExpression="LenExpression",NegateExpression="NegateExpression",PowExpression="PowExpression",
  IndexExpression="IndexExpression",FunctionCallExpression="FunctionCallExpression",
  PassSelfFunctionCallExpression="PassSelfFunctionCallExpression",VariableExpression="VariableExpression",
  FunctionLiteralExpression="FunctionLiteralExpression",TableConstructorExpression="TableConstructorExpression",
  TableEntry="TableEntry",KeyedTableEntry="KeyedTableEntry",NopStatement="NopStatement",
  IfElseExpression="IfElseExpression",
}
local ep={
  [AK.BooleanExpression]=0,[AK.NumberExpression]=0,[AK.StringExpression]=0,[AK.NilExpression]=0,[AK.VarargExpression]=0,
  [AK.OrExpression]=12,[AK.AndExpression]=11,[AK.LessThanExpression]=10,[AK.GreaterThanExpression]=10,
  [AK.LessThanOrEqualsExpression]=10,[AK.GreaterThanOrEqualsExpression]=10,[AK.NotEqualsExpression]=10,[AK.EqualsExpression]=10,
  [AK.StrCatExpression]=9,[AK.AddExpression]=8,[AK.SubExpression]=8,[AK.MulExpression]=7,[AK.DivExpression]=7,[AK.ModExpression]=7,
  [AK.NotExpression]=5,[AK.LenExpression]=5,[AK.NegateExpression]=5,[AK.PowExpression]=4,
  [AK.IndexExpression]=1,[AK.AssignmentIndexing]=1,[AK.FunctionCallExpression]=2,[AK.PassSelfFunctionCallExpression]=2,
  [AK.VariableExpression]=0,[AK.AssignmentVariable]=0,[AK.FunctionLiteralExpression]=3,[AK.TableConstructorExpression]=3,
}
local A={}
A.AstKind=AK
function A.astKindExpressionToNumber(k)return ep[k]or 100 end
function A.ConstantNode(v)if v==nil then return A.NilExpression()end;if type(v)=="string" then return A.StringExpression(v)end;if type(v)=="number" then return A.NumberExpression(v)end;if type(v)=="boolean" then return A.BooleanExpression(v)end end
function A.NopStatement()return{kind=AK.NopStatement}end
function A.TopNode(b,gs)return{kind=AK.TopNode,body=b,globalScope=gs}end
function A.Block(s,sc)return{kind=AK.Block,statements=s,scope=sc}end
function A.TableEntry(v)return{kind=AK.TableEntry,value=v}end
function A.KeyedTableEntry(k,v)return{kind=AK.KeyedTableEntry,key=k,value=v}end
function A.TableConstructorExpression(e)return{kind=AK.TableConstructorExpression,entries=e}end
function A.BreakStatement(l,s)return{kind=AK.BreakStatement,loop=l,scope=s}end
function A.ContinueStatement(l,s)return{kind=AK.ContinueStatement,loop=l,scope=s}end
function A.DoStatement(b)return{kind=AK.DoStatement,body=b}end
function A.ReturnStatement(a)return{kind=AK.ReturnStatement,args=a}end
function A.WhileStatement(b,c,p)return{kind=AK.WhileStatement,body=b,condition=c,parentScope=p}end
function A.RepeatStatement(c,b,p)return{kind=AK.RepeatStatement,body=b,condition=c,parentScope=p}end
function A.ForStatement(sc,id,init,fin,inc,b,p)return{kind=AK.ForStatement,scope=sc,id=id,initialValue=init,finalValue=fin,incrementBy=inc,body=b,parentScope=p}end
function A.ForInStatement(sc,vars,exprs,b,p)return{kind=AK.ForInStatement,scope=sc,ids=vars,vars=vars,expressions=exprs,body=b,parentScope=p}end
function A.IfStatement(c,b,ei,eb)return{kind=AK.IfStatement,condition=c,body=b,elseifs=ei,elsebody=eb}end
function A.AssignmentStatement(l,r)assert(#l>=1);return{kind=AK.AssignmentStatement,lhs=l,rhs=r}end
function A.CompoundAddStatement(l,r)return{kind=AK.CompoundAddStatement,lhs=l,rhs=r}end
function A.CompoundSubStatement(l,r)return{kind=AK.CompoundSubStatement,lhs=l,rhs=r}end
function A.CompoundMulStatement(l,r)return{kind=AK.CompoundMulStatement,lhs=l,rhs=r}end
function A.CompoundDivStatement(l,r)return{kind=AK.CompoundDivStatement,lhs=l,rhs=r}end
function A.CompoundModStatement(l,r)return{kind=AK.CompoundModStatement,lhs=l,rhs=r}end
function A.CompoundPowStatement(l,r)return{kind=AK.CompoundPowStatement,lhs=l,rhs=r}end
function A.CompoundConcatStatement(l,r)return{kind=AK.CompoundConcatStatement,lhs=l,rhs=r}end
function A.FunctionCallStatement(b,a)return{kind=AK.FunctionCallStatement,base=b,args=a}end
function A.PassSelfFunctionCallStatement(b,n,a)return{kind=AK.PassSelfFunctionCallStatement,base=b,passSelfFunctionName=n,args=a}end
function A.FunctionDeclaration(sc,id,idx,a,b)return{kind=AK.FunctionDeclaration,scope=sc,baseScope=sc,id=id,baseId=id,indices=idx,args=a,body=b,getName=function(self)return self.scope:getVariableName(self.id)end}end
function A.LocalFunctionDeclaration(sc,id,a,b)return{kind=AK.LocalFunctionDeclaration,scope=sc,id=id,args=a,body=b,getName=function(self)return self.scope:getVariableName(self.id)end}end
function A.LocalVariableDeclaration(sc,ids,ex)return{kind=AK.LocalVariableDeclaration,scope=sc,ids=ids,expressions=ex}end
function A.VarargExpression()return{kind=AK.VarargExpression,isConstant=false}end
function A.NilExpression()return{kind=AK.NilExpression,isConstant=true,value=nil}end
function A.BooleanExpression(v)return{kind=AK.BooleanExpression,isConstant=true,value=v}end
function A.NumberExpression(v)return{kind=AK.NumberExpression,isConstant=true,value=v}end
function A.StringExpression(v)return{kind=AK.StringExpression,isConstant=true,value=v}end
local function bc(kind,l,r,op)if l.isConstant and r.isConstant then local ok,v=pcall(op,l.value,r.value);if ok then return A.ConstantNode(v)end end;return{kind=kind,lhs=l,rhs=r,isConstant=false}end
function A.OrExpression(l,r,s)if s then return bc(AK.OrExpression,l,r,function(a,b)return a or b end)end;return{kind=AK.OrExpression,lhs=l,rhs=r,isConstant=false}end
function A.AndExpression(l,r,s)if s then return bc(AK.AndExpression,l,r,function(a,b)return a and b end)end;return{kind=AK.AndExpression,lhs=l,rhs=r,isConstant=false}end
function A.LessThanExpression(l,r,s)if s then return bc(AK.LessThanExpression,l,r,function(a,b)return a<b end)end;return{kind=AK.LessThanExpression,lhs=l,rhs=r,isConstant=false}end
function A.GreaterThanExpression(l,r,s)if s then return bc(AK.GreaterThanExpression,l,r,function(a,b)return a>b end)end;return{kind=AK.GreaterThanExpression,lhs=l,rhs=r,isConstant=false}end
function A.LessThanOrEqualsExpression(l,r,s)if s then return bc(AK.LessThanOrEqualsExpression,l,r,function(a,b)return a<=b end)end;return{kind=AK.LessThanOrEqualsExpression,lhs=l,rhs=r,isConstant=false}end
function A.GreaterThanOrEqualsExpression(l,r,s)if s then return bc(AK.GreaterThanOrEqualsExpression,l,r,function(a,b)return a>=b end)end;return{kind=AK.GreaterThanOrEqualsExpression,lhs=l,rhs=r,isConstant=false}end
function A.NotEqualsExpression(l,r,s)if s then return bc(AK.NotEqualsExpression,l,r,function(a,b)return a~=b end)end;return{kind=AK.NotEqualsExpression,lhs=l,rhs=r,isConstant=false}end
function A.EqualsExpression(l,r,s)if s then return bc(AK.EqualsExpression,l,r,function(a,b)return a==b end)end;return{kind=AK.EqualsExpression,lhs=l,rhs=r,isConstant=false}end
function A.StrCatExpression(l,r,s)if s then return bc(AK.StrCatExpression,l,r,function(a,b)return a..b end)end;return{kind=AK.StrCatExpression,lhs=l,rhs=r,isConstant=false}end
function A.AddExpression(l,r,s)if s then return bc(AK.AddExpression,l,r,function(a,b)return a+b end)end;return{kind=AK.AddExpression,lhs=l,rhs=r,isConstant=false}end
function A.SubExpression(l,r,s)if s then return bc(AK.SubExpression,l,r,function(a,b)return a-b end)end;return{kind=AK.SubExpression,lhs=l,rhs=r,isConstant=false}end
function A.MulExpression(l,r,s)if s then return bc(AK.MulExpression,l,r,function(a,b)return a*b end)end;return{kind=AK.MulExpression,lhs=l,rhs=r,isConstant=false}end
function A.DivExpression(l,r,s)if s and r.value~=0 then return bc(AK.DivExpression,l,r,function(a,b)return a/b end)end;return{kind=AK.DivExpression,lhs=l,rhs=r,isConstant=false}end
function A.ModExpression(l,r,s)if s then return bc(AK.ModExpression,l,r,function(a,b)return a%b end)end;return{kind=AK.ModExpression,lhs=l,rhs=r,isConstant=false}end
function A.PowExpression(l,r,s)if s then return bc(AK.PowExpression,l,r,function(a,b)return a^b end)end;return{kind=AK.PowExpression,lhs=l,rhs=r,isConstant=false}end
function A.NotExpression(r,s)if s and r.isConstant then local ok,v=pcall(function()return not r.value end);if ok then return A.ConstantNode(v)end end;return{kind=AK.NotExpression,rhs=r,isConstant=false}end
function A.NegateExpression(r,s)if s and r.isConstant then local ok,v=pcall(function()return-r.value end);if ok then return A.ConstantNode(v)end end;return{kind=AK.NegateExpression,rhs=r,isConstant=false}end
function A.LenExpression(r,s)if s and r.isConstant then local ok,v=pcall(function()return#r.value end);if ok then return A.ConstantNode(v)end end;return{kind=AK.LenExpression,rhs=r,isConstant=false}end
function A.IndexExpression(b,i)return{kind=AK.IndexExpression,base=b,index=i,isConstant=false}end
function A.AssignmentIndexing(b,i)return{kind=AK.AssignmentIndexing,base=b,index=i,isConstant=false}end
function A.FunctionCallExpression(b,a)return{kind=AK.FunctionCallExpression,base=b,args=a}end
function A.PassSelfFunctionCallExpression(b,n,a)return{kind=AK.PassSelfFunctionCallExpression,base=b,passSelfFunctionName=n,args=a}end
function A.FunctionLiteralExpression(a,b)return{kind=AK.FunctionLiteralExpression,args=a,body=b}end
function A.VariableExpression(sc,id)if id==nil then print("NIL ID! trace:") print(debug.traceback()) end sc:addReference(id);return{kind=AK.VariableExpression,scope=sc,id=id,getName=function(self)return self.scope:getVariableName(self.id)end}end
function A.AssignmentVariable(sc,id)sc:addReference(id);return{kind=AK.AssignmentVariable,scope=sc,id=id,getName=function(self)return self.scope:getVariableName(self.id)end}end
function A.IfElseExpression(c,t,f)return{kind=AK.IfElseExpression,condition=c,true_value=t,false_value=f}end
return A
