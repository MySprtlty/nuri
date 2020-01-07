module Nuri.Codegen.Stmt where

import           Control.Monad.RWS                        ( tell
                                                          , execRWS
                                                          )
import           Control.Lens                             ( view )

import           Text.Megaparsec.Pos                      ( Pos )

import qualified Data.Set.Ordered              as S

import           Nuri.Stmt
import           Nuri.ASTNode
import           Nuri.Codegen.Expr

import           Haneul.Builder
import           Haneul.Constant
import qualified Haneul.Instruction            as Inst
import           Haneul.Instruction                       ( AnnInstruction
                                                            ( AnnInst
                                                            )
                                                          , prependInst
                                                          )

compileStmt :: Stmt -> Builder ()
compileStmt stmt@(ExprStmt expr) = do
  compileExpr expr
  tell [AnnInst (getSourceLine stmt) Inst.Pop]
compileStmt stmt@(Return expr) = do
  compileExpr expr
  tell [AnnInst (getSourceLine stmt) Inst.Return]
compileStmt (Assign pos ident expr) = do
  compileExpr expr
  storeVar pos ident
compileStmt (If pos cond thenStmt elseStmt') = do
  compileExpr cond
  st    <- get
  depth <- ask
  let (thenInternal, thenInsts) = execRWS (compileStmt thenStmt) (depth + 1) st
  case elseStmt' of
    Just elseStmt -> do
      let (elseInternal, elseInsts) =
            execRWS (compileStmt elseStmt) (depth + 1) thenInternal
          thenInsts' = prependInst
            pos
            (Inst.JmpForward (fromIntegral $ length elseInsts))
            thenInsts
      tell [AnnInst pos (Inst.PopJmpIfFalse (fromIntegral $ length thenInsts'))]
      put thenInternal
      tell thenInsts'
      put elseInternal
      tell elseInsts
    Nothing -> do
      tell [AnnInst pos (Inst.PopJmpIfFalse (fromIntegral $ length thenInsts))]
      put thenInternal
      tell thenInsts

compileStmt While{}                               = undefined
compileStmt (FuncDecl pos funcName argNames body) = do
  depth <- ask
  let (internal, code) = execRWS
        (compileStmt body)
        (depth + 1)
        (defaultInternal { _internalVarNames = S.fromList argNames })
      funcObject = ConstFunc
        (FuncObject { _funcArity      = fromIntegral (length argNames)
                    , _funcBody       = code
                    , _funcConstTable = view internalConstTable internal
                    , _funcVarNames   = view internalVarNames internal
                    }
        )
  funcObjectIndex <- addConstant funcObject
  funcNameIndex   <- addVarName funcName
  tell
    [ AnnInst pos (Inst.Push funcObjectIndex)
    , AnnInst pos (Inst.Store funcNameIndex)
    ]

storeVar :: Pos -> String -> Builder ()
storeVar pos ident = do
  index <- addVarName ident
  tell [AnnInst pos (Inst.Store index)]


