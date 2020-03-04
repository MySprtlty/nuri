module Haneul.Builder where

import           Control.Monad.RWS                        ( RWS
                                                          , tell
                                                          )
import           Control.Lens                             ( modifying
                                                          , use
                                                          , uses
                                                          , element
                                                          , (.~)
                                                          , view
                                                          )

import qualified Data.List                     as L
import           Data.Set.Ordered                         ( (|>)
                                                          , findIndex
                                                          , OSet
                                                          )
import           Data.List                                ( (!!) )

import           Text.Megaparsec.Pos                      ( Pos )

import           Haneul.Instruction
import           Haneul.Constant
import           Haneul.BuilderInternal


type Builder = RWS [OSet String] MarkedCode BuilderInternal

-- addVarName :: String -> Builder Int32
-- addVarName ident = do
--   depth <- ask
--   modifying internalVarNames (|> (ident, depth))
--   names <- use internalVarNames
--   let (Just index) = findIndex (ident, depth) names
--   return $ fromIntegral index

addConstant :: Constant -> Builder Word32
addConstant value = do
  modifying internalConstTable (|> value)
  table <- use internalConstTable
  let (Just index) = findIndex value table
  return $ fromIntegral index

addVarName :: Word8 -> String -> Builder Word32
addVarName depth value = do
  modifying internalVarNames (++ [(depth, value)])
  table <- use internalVarNames
  let (Just index) = L.elemIndex (depth, value) table
  return $ fromIntegral index

addInternalString :: String -> Builder Word32
addInternalString value = do
  modifying internalStrings (|> value)
  table <- use internalStrings
  let (Just index) = findIndex value table
  return $ fromIntegral index

addFreeVar :: (Word8, Word8) -> Builder Word32
addFreeVar value = do
  modifying internalFreeVars (|> value)
  table <- use internalFreeVars
  let (Just index) = findIndex value table
  return $ fromIntegral index

createMark :: Builder Word32
createMark = do
  modifying internalMarks (++ [0])
  uses internalMarks (flip (-) 1 . genericLength)

setMark :: Word32 -> Builder ()
setMark markIndex = do
  offset <- use internalOffset
  modifying internalMarks (element (fromIntegral markIndex) .~ offset)

clearMarks :: BuilderInternal -> MarkedCode -> Code
clearMarks internal markedCode = fmap (unmarkInst internal) <$> markedCode

unmarkInst :: BuilderInternal -> MarkedInstruction -> Instruction
unmarkInst internal inst = case inst of
  Jmp           v -> Jmp (unmark v)
  PopJmpIfFalse v -> PopJmpIfFalse (unmark v)
  Push          v -> Push v
  Pop             -> Pop
  StoreGlobal v   -> StoreGlobal v
  Load        v   -> Load v
  Store       v   -> Store v
  LoadDeref   v   -> LoadDeref v
  LoadGlobal  v   -> LoadGlobal v
  Call        v   -> Call v
  FreeVar     v   -> FreeVar v
  Add             -> Add
  Subtract        -> Subtract
  Multiply        -> Multiply
  Divide          -> Divide
  Mod             -> Mod
  Equal           -> Equal
  LessThan        -> LessThan
  GreaterThan     -> GreaterThan
  Negate          -> Negate
 where
  unmark (Mark index) =
    let marks = view internalMarks internal in marks !! fromIntegral index

tellCode :: MarkedCode -> Builder ()
tellCode code = do
  modifying internalOffset (+ genericLength code)
  tell code

tellInst :: Pos -> MarkedInstruction -> Builder ()
tellInst pos inst = tellCode [(pos, inst)]

