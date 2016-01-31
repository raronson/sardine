{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

import           BuildInfo_ambiata_sardine_compiler

import           Control.Monad.IO.Class (liftIO)

import           Data.Text (Text)
import qualified Data.Text.IO as T

import           Language.Thrift.Parser.Trifecta (thriftIDL)

import           P

import           Sardine.Compiler
import           Sardine.Haskell.Pretty
import           Sardine.Error

import           System.IO (BufferMode(..), hSetBuffering)
import           System.IO (FilePath)
import           System.IO (IO, stdout, stderr, print, putStrLn)
import           System.Exit (exitSuccess)

import           Text.Trifecta.Parser (parseFromFileEx)
import           Text.Trifecta.Result (Result(..))
import           Text.Shakespeare.Text (sbt)

import           X.Control.Monad.Trans.Either (EitherT, left, hoistEither)
import           X.Control.Monad.Trans.Either.Exit (orDie)

import           X.Options.Applicative (SafeCommand(..), safeCommand)
import           X.Options.Applicative (RunType(..), dispatch)
import           X.Options.Applicative (Parser(..), metavar, help, strArgument)


main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  dispatch parser >>= \case
    VersionCommand ->
      putStrLn buildInfoVersion >> exitSuccess
    RunCommand DryRun c ->
      print c >> exitSuccess
    RunCommand RealRun c ->
      orDie renderSardineError (run c)

data SardineCommand =
    SardineCompile FilePath
    deriving (Eq, Show)

parser :: Parser (SafeCommand SardineCommand)
parser =
  safeCommand $
    SardineCompile <$> pThriftFile

pThriftFile :: Parser FilePath
pThriftFile =
  strArgument $
    metavar "FILE" <>
    help ".thrift interface file to compile"

run :: SardineCommand -> EitherT SardineError IO ()
run c = case c of
  SardineCompile path ->
    sardineCompile path

sardineCompile :: FilePath -> EitherT SardineError IO ()
sardineCompile path = do
  rthrift <- liftIO $ parseFromFileEx thriftIDL path
  case rthrift of
    Failure doc ->
      left $ SardineParserError doc
    Success thrift -> do
      haskell <- firstT SardineCompilerError . hoistEither . runCompiler $
        moduleOfProgram path thrift
      code <- firstT SardinePrettyError . hoistEither $
        ppModule haskell
      liftIO $ T.putStr header
      liftIO $ print code

-- generated using:
--   cowsay -f dragon "<msg>"
header :: Text
header =
  [sbt|--   ______________________________________
      |--  / This is generated code, only edit if \
      |--  \ you're feeling lucky.                /
      |--   --------------------------------------
      |--        \                    / \  //\
      |--         \    |\___/|      /   \//  \\
      |--              /0  0  \__  /    //  | \ \
      |--             /     /  \/_/    //   |  \  \
      |--             @_^_@'/   \/_   //    |   \   \
      |--             //_^_/     \/_ //     |    \    \
      |--          ( //) |        \///      |     \     \
      |--        ( / /) _|_ /   )  //       |      \     _\
      |--      ( // /) '/,_ _ _/  ( ; -.    |    _ _\.-~        .-~~~^-.
      |--    (( / / )) ,-{        _      `-.|.-~-.           .~         `.
      |--   (( // / ))  '/\      /                 ~-. _ .-~      .-~^-.  \
      |--   (( /// ))      `.   {            }                   /      \  \
      |--    (( / ))     .----~-.\        \-'                 .~         \  `. \^-.
      |--               ///.----..>        \             _ -~             `.  ^-`  ^-_
      |--                 ///-._ _ _ _ _ _ _}^ - - - - ~                     ~-- ,.-~
      |--                                                                    /.-~
      |]
