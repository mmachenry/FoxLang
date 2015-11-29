module Eval (evalModule, evalExpr, Value(..), Error(..)) where

import Ast

data Error = Error String
    deriving (Eq, Show)

data Value =
      ValNum Integer
    | ValBool Bool
    deriving (Eq, Show)

evalModule :: Module -> Either Error Value
evalModule (Module definitions) = undefined

evalExpr :: Expr -> Either Error Value
evalExpr ast = case ast of
    ExprVar id -> undefined
    ExprApp func args -> undefined
    ExprAbs params body -> undefined
    ExprLetBind id expr -> undefined
    ExprEffectBind id expr -> undefined
    ExprRun exprs -> undefined

    ExprIfThenElse test consequent alternate -> undefined
    ExprMatch expr cases -> undefined
    ExprRepeat numTimes exprs -> undefined
    ExprStatementBlock exprs -> undefined
    ExprBinOp binOp lhs rhs -> undefined
    ExprUnaryOp unaryOp operand -> undefined

    ExprAlloc expr -> undefined
    ExprRead expr -> undefined
    ExprWrite lhs rhs -> undefined

    ExprNum integer -> Right $ ValNum integer
