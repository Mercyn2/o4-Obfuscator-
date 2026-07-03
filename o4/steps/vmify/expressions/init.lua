local A  = require "ast"
local AK = A.AstKind
local p  = "steps.vmify.expressions."
local function r(n) return require(p .. n) end

local H = {}
H[AK.StringExpression]      = r "string"
H[AK.NumberExpression]      = r "number"
H[AK.BooleanExpression]     = r "boolean"
H[AK.NilExpression]         = r "nil"
H[AK.VariableExpression]    = r "variable"
H[AK.FunctionCallExpression]= r "function_call"
H[AK.PassSelfFunctionCallExpression] = r "pass_self_function_call"
H[AK.IndexExpression]       = r "index"
H[AK.NotExpression]         = r "not"
H[AK.NegateExpression]      = r "negate"
H[AK.LenExpression]         = r "len"
H[AK.OrExpression]          = r "or"
H[AK.AndExpression]         = r "and"
H[AK.TableConstructorExpression] = r "table_constructor"
H[AK.FunctionLiteralExpression]  = r "function_literal"
H[AK.VarargExpression]      = r "vararg"
local bh = r "binary"
H[AK.LessThanExpression]           = bh
H[AK.GreaterThanExpression]        = bh
H[AK.LessThanOrEqualsExpression]   = bh
H[AK.GreaterThanOrEqualsExpression]= bh
H[AK.NotEqualsExpression]          = bh
H[AK.EqualsExpression]             = bh
H[AK.StrCatExpression]             = bh
H[AK.AddExpression]                = bh
H[AK.SubExpression]                = bh
H[AK.MulExpression]                = bh
H[AK.DivExpression]                = bh
H[AK.ModExpression]                = bh
H[AK.PowExpression]                = bh
return H
