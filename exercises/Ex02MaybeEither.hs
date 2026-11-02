{-# OPTIONS_GHC -Wall #-}

-- | 阶段 2：Maybe / Either —— 把"可能失败"写进类型里
--
-- Rust 对照：
--   Maybe a  <->  Option<a>
--   Either e a  <->  Result<a, e>     （注意：Haskell 的"错误类型"在前）
--   Just x   <->  Some(x)
--   Left e   <->  Err(e)  /  Nothing <-> None
--
-- 关键收益：函数签名就把"可能失败"暴露出来了，调用方无法假装它不会失败。
-- Haskell 里没有 @throw@（除非你用 IO 的异常），失败必须是返回值。
module Main (main) where

import Spec (checkEq, runChecks)
import Text.Read (readMaybe)

-- 工具调用的参数表。Rust 里你会用 HashMap<String, String>，
-- 这里用关联列表就够，而且 @lookup@ 是 Prelude 自带的。
-- newtype 让它和裸的 [(String, String)] 区分开。
newtype ToolArgs = ToolArgs [(String, String)]
  deriving (Eq, Show)

-- ============================================================
-- 1. Maybe：解析失败就是 Nothing
-- ============================================================

-- TODO 1：把字符串解析成超时毫秒数。
--   规则：必须是整数，且落在 1 .. 60000 的闭区间内，否则 Nothing。
--   提示：Text.Read.readMaybe :: Read a => String -> Maybe a
--         注意它的返回类型是多态的，这里需要标注成 Maybe Int
--         （不标注会触发 -Wtype-defaults，就像你 test.hs 里那样）。
parseTimeout :: String -> Maybe Int
parseTimeout = undefined

-- ============================================================
-- 2. Either：失败时要带原因
-- ============================================================

-- TODO 2：取一个参数，取不到就 Left "missing argument: <name>"。
--   提示：Prelude 的 @lookup@ 直接能用在关联列表上。
lookupArg :: String -> ToolArgs -> Either String String
lookupArg = undefined

-- ============================================================
-- 3. do 记法：这就是 Rust 的 ? 运算符
-- ============================================================
--
-- Rust:                              Haskell:
--   let raw = lookup_arg("timeout")?;   raw <- lookupArg "timeout" args
--   match parse(raw) {                  case parseTimeout raw of
--       Some(n) => n,                      Just n -> ...
--       None => return Err(..),            Nothing -> Left ...
--   }
--
-- 阶段 3 会解释 <- 到底是什么（它就是 >>= 的语法糖）。
-- 现在只需要知道：**对 Either 用 do，行为等价于一路 ? 下去**。

-- TODO 3：先取参数，再解析成 Int。
--   取不到 -> Left "missing argument: timeout"（lookupArg 自己会给）
--   解析失败 -> Left "invalid timeout: <原始字符串>"
firstTimeout :: ToolArgs -> Either String Int
firstTimeout = undefined

-- ============================================================
-- 4. traverse：把 [a] 变成 f [a]
-- ============================================================

-- TODO 4：批量解析。任何一个失败就整体失败（fail-fast），
-- 错误信息用第一个失败的原始字符串："invalid timeout: <s>"。
-- 提示：traverse :: (a -> Either e b) -> [a] -> Either e [b]
--       这就是 Rust 的 `strings.iter().map(f).collect::<Result<Vec<_>, _>>()`
parseAllTimeouts :: [String] -> Either String [Int]
parseAllTimeouts = undefined

-- ============================================================
-- 5. 消除 Either：either 就是 Result::unwrap_or / map_err 的组合
-- ============================================================

-- TODO 5：拿不到或者解析失败时返回 fallback。
-- 提示：either :: (e -> b) -> (a -> b) -> Either e a -> b
--       对比 Rust: result.map_err(|_| fallback).unwrap_or(fallback)
timeoutOr :: Int -> ToolArgs -> Int
timeoutOr = undefined

-- ============================================================
-- 测试（不要改这里）
-- ============================================================

sampleArgs :: ToolArgs
sampleArgs = ToolArgs [("path", "notes.md"), ("timeout", "3000")]

noTimeoutArgs :: ToolArgs
noTimeoutArgs = ToolArgs [("path", "notes.md")]

badTimeoutArgs :: ToolArgs
badTimeoutArgs = ToolArgs [("timeout", "abc")]

dupArgs :: ToolArgs
dupArgs = ToolArgs [("timeout", "1000"), ("timeout", "9000")]

main :: IO ()
main =
  runChecks
    [ checkEq "parseTimeout \"5000\"" (Just 5000) (parseTimeout "5000")
    , checkEq "parseTimeout \"60000\"（上界）" (Just 60000) (parseTimeout "60000")
    , checkEq "parseTimeout \"0\"（下界外）" Nothing (parseTimeout "0")
    , checkEq "parseTimeout \"60001\"" Nothing (parseTimeout "60001")
    , checkEq "parseTimeout \"-5\"" Nothing (parseTimeout "-5")
    , checkEq "parseTimeout \"abc\"" Nothing (parseTimeout "abc")
    , checkEq "parseTimeout \"\"" Nothing (parseTimeout "")
    , checkEq "lookupArg 命中" (Right "notes.md") (lookupArg "path" sampleArgs)
    , checkEq
        "lookupArg 未命中"
        (Left "missing argument: model")
        (lookupArg "model" sampleArgs)
    , checkEq "lookup 重复 key 取第一个" (Right "1000") (lookupArg "timeout" dupArgs)
    , checkEq "firstTimeout 正常" (Right 3000) (firstTimeout sampleArgs)
    , checkEq
        "firstTimeout 缺参数"
        (Left "missing argument: timeout")
        (firstTimeout noTimeoutArgs)
    , checkEq
        "firstTimeout 解析失败"
        (Left "invalid timeout: abc")
        (firstTimeout badTimeoutArgs)
    , checkEq "parseAllTimeouts 全成功" (Right [100, 200]) (parseAllTimeouts ["100", "200"])
    , checkEq "parseAllTimeouts 空列表" (Right []) (parseAllTimeouts [])
    , checkEq
        "parseAllTimeouts 第一个失败即返回"
        (Left "invalid timeout: x")
        (parseAllTimeouts ["100", "x", "y"])
    , checkEq "timeoutOr 有值时用它" 3000 (timeoutOr 9999 sampleArgs)
    , checkEq "timeoutOr 缺值时用默认" 9999 (timeoutOr 9999 noTimeoutArgs)
    , checkEq "timeoutOr 解析失败用默认" 9999 (timeoutOr 9999 badTimeoutArgs)
    ]
