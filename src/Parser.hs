module Parser (readProgramFile, readStr, definitions, expr, pattern) where

import Ast
import Text.ParserCombinators.Parsec hiding ((<|>), many)
import Text.Parsec.Expr
import Text.Parsec.Language (emptyDef)
import Text.ParserCombinators.Parsec.Number (fractional2)
import qualified Text.Parsec.Token as Token
import Control.Applicative

readProgramFile :: String -> IO (Either ParseError Module)
readProgramFile filename = do
    fileContents <- readFile filename
    return $ case parse (allOf definitions) filename fileContents of
        Left parseError -> Left $ parseError
        Right m -> Right m

readStr :: Parser a -> String -> Either ParseError a
readStr parser = parse (allOf parser) "fox"

allOf :: Parser a -> Parser a
allOf p = Token.whiteSpace lexer *> p <* eof

--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

lexer :: Token.TokenParser ()
lexer = Token.makeTokenParser $ emptyDef {
    --Token.commentLine = "#",
    Token.reservedOpNames =
        ["=","<-","->",":"]
        ++ concat binaryOperators
        ++ concat unaryOperators,
    Token.reservedNames = [
        "pure", "partial", "total", "divergent",
        "if", "then", "else",
        "match", "repeat",
        "run"]
    }

binaryOperators :: [[String]]
binaryOperators = [
    ["*","/"],
    ["+", "-"],
    [">","<",">=","<="],
    ["==","!="],
    ["&&"],
    ["||"],
    [":="]
    ]

unaryOperators :: [[String]]
unaryOperators = [["!"]]

parens :: Parser a -> Parser a
parens = Token.parens lexer

reserved :: String -> Parser ()
reserved = Token.reserved lexer

reservedOp :: String -> Parser ()
reservedOp = Token.reservedOp lexer

identifier :: Parser String
identifier = Token.identifier lexer

commaSep :: Parser a -> Parser [a]
commaSep = Token.commaSep lexer

semiSep :: Parser a -> Parser [a]
semiSep = Token.semiSep lexer

braces :: Parser a -> Parser a
braces = Token.braces lexer

--------------------------------------------------------------------------------
-- Parser
--------------------------------------------------------------------------------

definitions :: Parser Module
definitions = Module <$> many definition

definition :: Parser Definition
definition = Definition
    <$> identifier
    <*> parens (commaSep parameter)
    <*> braces manyExpr

manyExpr :: Parser Expr
manyExpr = letBind <|> effectBind <|> compoundExpr

letBind :: Parser Expr
letBind = ExprLetBind
    <$> try (identifier <* reservedOp "=")
    <*> (expr <* reservedOp ";")
    <*> manyExpr

effectBind :: Parser Expr
effectBind = ExprEffectBind
    <$> try (identifier <* reservedOp "<-")
    <*> (expr <* reservedOp ";")
    <*> manyExpr

compoundExpr :: Parser Expr
compoundExpr = do
    expr1 <- statement <|> expr
    rest <- fmap Just (reservedOp ";" *> manyExpr) <|> pure Nothing
    case rest of
        Just otherExprs -> pure $ ExprCompound expr1 otherExprs
        Nothing -> pure expr1

-- Statements are expressions that have the form "name { ... }" and do not
-- have a semicolon after them when appearing in a block.

statement :: Parser Expr
statement = repeat_ <|> run

repeat_ :: Parser Expr
repeat_ = ExprRepeat
    <$> (reserved "repeat" *> parens expr)
    <*> braces manyExpr

run :: Parser Expr
run = ExprRun <$> (reserved "run" *> braces manyExpr)

match :: Parser Expr
match = ExprMatch
    <$> (reserved "match" *> expr)
    <*> braces (Token.semiSep1 lexer matchClause)

matchClause :: Parser (Pattern, Expr)
matchClause = (,) <$> pattern <*> (reservedOp "->" *> expr)

-- end statements

parameter :: Parser Parameter
parameter = Parameter
    <$> identifier
    <*> option TypeInferred (reservedOp ":" *> type_)

type_ :: Parser Type
type_ =
    try (TypeFunction <$> (parens (commaSep type_) <|> fmap pure nonArrowType)
                      <*> (reservedOp "->" *> effect)
                      <*> type_)
    <|> nonArrowType

nonArrowType :: Parser Type
nonArrowType = typeVar <|> typeIdentifier

typeVar :: Parser Type
typeVar = TypeVar <$> (reservedOp "'" *> identifier)

typeIdentifier :: Parser Type
typeIdentifier = TypeIdentifier <$> identifier

effect :: Parser Effect
effect = option EffectInferred (
        reserved "pure" *> pure EffectPure
    <|> reserved "partial" *> pure EffectPartial
    <|> reserved "divergent" *> pure EffectDivergent
    <|> reserved "total" *> pure EffectTotal
    )

pattern :: Parser Pattern
pattern =
         try (PatternApp <$> identifier <*> parens (commaSep pattern))
     <|> PatternId <$> identifier

expr :: Parser Expr
expr =
        ifThenElse
    <|> formula

ifThenElse :: Parser Expr
ifThenElse = liftA3 ExprIfThenElse
    (reserved "if" *> expr)
    (reserved "then" *> expr)
    (reserved "else" *> expr)

formula :: Parser Expr
formula = buildExpressionParser table app <?> "formula"
    -- FIXME: this assumes all infix operators happen before all prefix
    where table = fmap (fmap prefix) unaryOperators
                    ++ fmap (fmap infl) binaryOperators
          infl lex = Infix (reservedOp lex *> pure (\lhs rhs->ExprApp (ExprVar lex) [lhs,rhs]))
                                  AssocLeft
          prefix lex = Prefix (reservedOp lex *> pure (\arg->ExprApp (ExprVar lex) [arg]))

app :: Parser Expr
app = do
    a <- atom
    args <- many arguments
    pure $ foldl ExprApp a args

arguments :: Parser [Expr]
arguments = parens (commaSep expr)

atom :: Parser Expr
atom =
        variable
    <|> number
    <|> parens expr
    <|> braces manyExpr
    <?> "atom"

variable :: Parser Expr
variable = ExprVar <$> identifier

number :: Parser Expr
number = ExprLiteral . ValNum <$> (
    Token.whiteSpace lexer
    *> fractional2 False
    <* Token.whiteSpace lexer)

