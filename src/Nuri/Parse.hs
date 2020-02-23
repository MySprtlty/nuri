module Nuri.Parse where

import qualified Text.Megaparsec               as P
import           Text.Megaparsec                          ( (<?>) )
import qualified Text.Megaparsec.Char          as P
import qualified Text.Megaparsec.Char.Lexer    as L

type Parser = P.Parsec Void String

lineComment :: Parser ()
lineComment = L.skipLineComment "#"

blockComment :: Parser ()
blockComment = L.skipBlockComment "(*" "*)"

-- Space Consumer, 공백 문자 (개행 문자 제외) 를 스킵할 때 쓰입니다.
sc :: Parser ()
sc = L.space (void $ P.takeWhile1P Nothing isSpace) lineComment blockComment
  where isSpace x = x == ' ' || x == '\t'

-- Space Consumer with Newline, 개행 문자를 포함한 공백 문자를 스킵할 때 쓰입니다.
scn :: Parser ()
scn = L.space P.space1 lineComment blockComment

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: String -> Parser String
symbol = L.symbol sc

reserved :: String -> Parser ()
reserved s =
  (lexeme . P.try)
      (sequence (P.char <$> toString s) *> P.notFollowedBy hangulSyllable)
    <?> concat ["'", s, "'"]

hangulSyllable :: Parser Char
hangulSyllable = P.hidden $ P.oneOf ['가' .. '힣']

hangulJamo :: Parser Char
hangulJamo = P.hidden $ P.oneOf (['ㄱ' .. 'ㅎ'] ++ ['ㅏ' .. 'ㅣ'])

getSourceLine :: Parser P.Pos
getSourceLine = P.sourceLine <$> P.getSourcePos
