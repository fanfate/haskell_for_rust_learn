-- | 极简测试框架。
--
-- 只依赖 base，避免引入 hspec / tasty 之类的外部包，
-- 让每个练习都能用 @runghc@ 直接跑起来。
--
-- 设计要点（也是 Haskell 的一个教学点）：
--   'Check' 里的 Bool 是惰性的 thunk。'runChecks' 用
--   'Control.Exception.evaluate' 在 try 里强制求值它，
--   于是学员把函数体写成 @undefined@ 时，看到的是一条
--   "运行时异常" 的失败信息，而不是整个程序崩溃。
module Spec
  ( Check
  , check
  , checkEq
  , runChecks
  ) where

import Control.Exception (SomeException, evaluate, try)
import System.Exit (exitFailure, exitSuccess)

data Check = Check
  { cLabel :: String
  , cPassed :: Bool
  , cDetail :: String
  }

-- | 断言布尔条件成立。
--
-- 注意这里**没有**用 guard（@| ok = ...@）：guard 会在构造 'Check'
-- 的时候就被求值，于是 @undefined@ 会在 'runChecks' 的 try 之外炸掉。
-- 把 Bool 原样塞进字段，它就是个惰性 thunk，可以留给 try 去强制。
check :: String -> Bool -> Check
check l ok = Check l ok "    结果为 False，期望 True"

-- | 断言 @actual == expected@。理由同上：不要写 guard。
checkEq :: (Eq a, Show a) => String -> a -> a -> Check
checkEq l expected actual =
  Check
    l
    (expected == actual)
    ( "    期望: " ++ show expected
        ++ "\n    实际: " ++ show actual
    )

render :: Check -> String
render c
  | cPassed c = "  [ok]   " ++ cLabel c
  | otherwise = "  [FAIL] " ++ cLabel c ++ "\n" ++ cDetail c

runChecks :: [Check] -> IO ()
runChecks checks = do
  putStrLn ""
  results <- mapM force checks
  mapM_ (putStrLn . render) results
  let total = length results
      failed = length (filter (not . cPassed) results)
  putStrLn ""
  putStrLn ("  " ++ show (total - failed) ++ "/" ++ show total ++ " passed")
  putStrLn ""
  if failed == 0 then exitSuccess else exitFailure
  where
    -- 让 undefined / error 变成一条失败信息，而不是让整个进程挂掉。
    force :: Check -> IO Check
    force c = do
      r <- try (evaluate (cPassed c)) :: IO (Either SomeException Bool)
      pure $ case r of
        Right ok -> c {cPassed = ok}
        Left e ->
          c
            { cPassed = False
            , cDetail = "    运行时异常: " ++ takeWhile (/= '\n') (show e)
            }
