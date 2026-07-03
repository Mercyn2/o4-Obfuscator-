local A  = require "ast"
local AK = A.AstKind
local p  = "steps.vmify.statements."
local function r(n) return require(p .. n) end

local H = {}
H[AK.ReturnStatement]            = r "return"
H[AK.LocalVariableDeclaration]   = r "local_variable_declaration"
H[AK.FunctionCallStatement]      = r "function_call"
H[AK.PassSelfFunctionCallStatement] = r "pass_self_function_call"
H[AK.LocalFunctionDeclaration]   = r "local_function_declaration"
H[AK.FunctionDeclaration]        = r "function_declaration"
H[AK.AssignmentStatement]        = r "assignment"
H[AK.IfStatement]                = r "if_statement"
H[AK.DoStatement]                = r "do_statement"
H[AK.WhileStatement]             = r "while_statement"
H[AK.RepeatStatement]            = r "repeat_statement"
H[AK.ForStatement]               = r "for_statement"
H[AK.ForInStatement]             = r "for_in_statement"
H[AK.BreakStatement]             = r "break_statement"
H[AK.ContinueStatement]          = r "continue_statement"
local ch = r "compound"
H[AK.CompoundAddStatement]    = ch
H[AK.CompoundSubStatement]    = ch
H[AK.CompoundMulStatement]    = ch
H[AK.CompoundDivStatement]    = ch
H[AK.CompoundModStatement]    = ch
H[AK.CompoundPowStatement]    = ch
H[AK.CompoundConcatStatement] = ch
return H
