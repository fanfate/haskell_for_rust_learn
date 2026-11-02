{-# OPTIONS_GHC -Wall #-}

-- | 阶段 3：类型类、Functor / Applicative / Monad、do 记法
--
-- 这是 Haskell 最核心也最容易吓退人的一块。好消息是：
--
--     **你已经会了。** Rust 的 @?@ 就是 Monad 的 >>=，你的 agent 代码里
--     每一条 @foo()?@ 都在做同一件事——把"成功就继续、失败就短路"从
--     控制流里抽出来变成一个可组合的值。
--
-- 本阶段分两部分：
--   A. 类型类 = trait（怎么写、和 trait 有什么不同）
--   B. 手写一个 Monad（"审计日志"效应），然后验证 do 记法就是 >>= 的糖
module Main (main) where

import Spec (checkEq, runChecks)

-- ============================================================
-- A. 类型类 = trait
-- ============================================================
--
-- Rust:                                        Haskell:
--   trait Tool {                                 class Tool a where
--       fn name(&self) -> String;                  toolName   :: a -> String
--       fn cost_ms(&self) -> i64 {                 toolCostMs :: a -> Int
--           self.cost_base()                       toolSummary :: a -> String
--       }                                          toolSummary t = ...   -- 默认实现
--   }                                            }
--   impl Tool for ReadTool { ... }               instance Tool ReadTool where
--   fn expensive<T: Tool>(t: &T) -> bool         expensive :: Tool a => a -> Bool
--
-- 三个关键差异：
--   1. 没有 self / &self。类型类方法就是普通函数，方法接收者靠位置区分。
--   2. 实例是**全局唯一**的：一个类型对一个类型类只能有一个 instance。
--      所以 Haskell 不需要 dyn Trait —— 约束在编译期解析（单态化）。
--      想要动态分发才需要显式的存在类型，那是另一回事。
--   3. instance 可以写在**任何地方**（只要 import 到），甚至可以给别人的
--      类型实现自己的类型类。这也带来"孤儿实例"问题，是要小心的地方。
class Tool a where
  toolName :: a -> String
  toolCostMs :: a -> Int
  toolSummary :: a -> String
  toolSummary t = toolName t <> " (" <> show (toolCostMs t) <> "ms)"

data ReadTool = ReadTool
  deriving (Eq, Show)

data ShellTool = ShellTool
  deriving (Eq, Show)

-- TODO 1：read_file，耗时 50ms
instance Tool ReadTool where
  toolName _ = "read_file"
  toolCostMs _ = 50

-- TODO 2：shell，耗时 2000ms
-- （别实现 toolSummary —— 让它走默认实现，体会 trait 默认方法）
instance Tool ShellTool where
  toolName _ = "shell"
  toolCostMs _ = 2000

-- TODO 3：耗时超过 1000ms 算昂贵。
-- Rust: fn expensive<T: Tool>(t: &T) -> bool { t.cost_ms() > 1000 }
expensive :: Tool a => a -> Bool
expensive t = toolCostMs t > 1000

-- ============================================================
-- B. 手写一个 Monad：审计日志
-- ============================================================
--
-- 你要实现的是 @newtype Audit a = Audit (a, [String])@，
-- 也就是 "一个值 + 一路上记下的日志"。等价于标准库的 Writer [String]。
--
-- 三个方法各自的含义：
--
--   fmap f (Audit (a, w))      = Audit (f a, w)
--       改值，**不动**日志。问你：为什么 fmap 不该改日志？
--
--   pure a                     = Audit (a, [])
--       提升一个值，不产生任何日志。
--
--   Audit (f, w1) <*> Audit (a, w2)
--                              = Audit (f a, w1 <> w2)
--       应用一个"带日志的函数"，日志按出现顺序拼接。
--
--   Audit (a, w) >>= k         = let Audit (b, w') = k a in Audit (b, w <> w')
--       先拿到 a，把它喂给 k 得到下一步，两段日志拼接。
--       注意 >>= 保证 w 里的日志一定在 w' 之前 —— 这就是"顺序"的来源。
--
-- ⚠ 坑：定义 @instance Monad Audit@ 之前，必须先有 Applicative Audit，
-- 而 Applicative 又需要 Functor。类型类有超类（superclass）约束，
-- 少了任何一个，GHC 会直接拒绝编译。顺序错了会看到经典的
-- "No instance for (Applicative Audit)" 报错。
newtype Audit a = Audit (a, [String])
  deriving (Eq, Show)

-- TODO 4
instance Functor Audit where
  fmap f (Audit (a, w)) = Audit (f a, w)

-- TODO 5
instance Applicative Audit where
  pure a = Audit (a, [])
  Audit (f, w1) <*> Audit (a, w2) = Audit (f a, w1 <> w2)

-- TODO 6
instance Monad Audit where
  Audit (a, w) >>= k = 
    let Audit (b, w') = k a
     in Audit (b, w <> w')

-- 现成的工具函数：写一条日志，不产生值
logMsg :: String -> Audit ()
logMsg msg = Audit ((), [msg])

-- ============================================================
-- C. do 记法就是 >>= 的糖
-- ============================================================
--
--   do { x <- m;   rest }   ==   m >>= \x -> rest
--   do { m;        rest }   ==   m >> rest          （m 的结果被丢弃）
--   do { let x = e; rest }  ==   let x = e in rest
--   do { pure e }           ==   pure e
--
-- 编译器干的活就这么点。do 之所以对 Either / Maybe / IO / Audit 都管用，
-- 是因为它们都有 Monad 实例 —— 也就是都定义了"怎样把两步串起来"。
-- 这就是 Monad 的全部意义：**一种通用的、可组合的"然后"**。

-- 已给出：一段用 do 写的计算
exampleDo :: Audit Int
exampleDo = do
  logMsg "a"
  x <- pure 1
  logMsg "b"
  pure (x + 1)

-- TODO 7：不用 do，只用 >>= 和 >>，写出完全等价的 exampleNoDo。
-- 提示：最后一步是 "pure (x+1)"，要把 x 传进去，所以需要 >>=；
--       前面丢结果的步骤用 >> 就行。
exampleNoDo :: Audit Int
exampleNoDo = logMsg "a" >> pure 1 >>= \x -> logMsg "b" >> pure (x + 1)

-- ============================================================
-- D. 综合：用 do 写一个带审计的预算扣减
-- ============================================================

-- TODO 8：按顺序处理每个 (工具名, 花费)，扣预算并记日志。
--   若 cost <= 剩余预算：
--       剩余 -= cost，日志 "ok <name> -<cost> => <left>"，把 name 记入成功列表
--   否则：
--       不扣，日志 "reject <name> cost <cost> > <left>"，不进列表
--   最终返回 (剩余预算, 成功的工具名列表)（保持输入顺序）。
--
-- 示例：spend 100 [("read",30),("shell",90)]
--   == Audit ((70, ["read"]), ["ok read -30 => 70", "reject shell cost 90 > 70"])
--
-- 提示：这是递归 + do。写一个辅助函数 go :: Int -> [String] -> [(String,Int)] -> Audit (Int,[String])，
--       left 是剩余预算，acc 是"倒序"的成功列表（最后 reverse 一下）。
spend :: Int -> [(String, Int)] -> Audit (Int, [String])
spend budget = go budget []
  where
    go left acc [] = pure (left, reverse acc)
    go left acc ((name, cost) : rest)
      | cost <= left = do
          let left' = left - cost
          logMsg ("ok " <> name <> " -" <> show cost <> " => " <> show left')
          go left' (name : acc) rest
      | otherwise = do
          logMsg ("reject " <> name <> " cost " <> show cost <> " > " <> show left)
          go left acc rest

-- ============================================================
-- 测试（不要改这里）
-- ============================================================

main :: IO ()
main =
  runChecks
    [ checkEq "toolName ReadTool" "read_file" (toolName ReadTool)
    , checkEq "toolName ShellTool" "shell" (toolName ShellTool)
    , checkEq "toolSummary 走默认实现" "shell (2000ms)" (toolSummary ShellTool)
    , checkEq "expensive ShellTool" True (expensive ShellTool)
    , checkEq "expensive ReadTool" False (expensive ReadTool)
    , checkEq "logMsg" (Audit ((), ["hi"]) :: Audit ()) (logMsg "hi")
    , checkEq "pure 不产生日志" (Audit (1, []) :: Audit Int) (pure 1)
    , checkEq
        "fmap 不动日志"
        (Audit (2, ["a"]) :: Audit Int)
        (fmap (+ 1) (Audit (1, ["a"])))
    , checkEq
        "<*> 按顺序拼接日志"
        (Audit (2, ["f", "x"]) :: Audit Int)
        (Audit ((+ 1), ["f"]) <*> Audit (1, ["x"]))
    , checkEq
        ">>= 日志顺序：先 w 后 w'"
        (Audit (2, ["a", "b"]) :: Audit Int)
        (logMsg "a" >> pure 1 >>= \x -> logMsg "b" >> pure (x + 1))
    , checkEq "exampleDo" (Audit (2, ["a", "b"]) :: Audit Int) exampleDo
    , checkEq "exampleNoDo == exampleDo" exampleDo exampleNoDo
    , checkEq
        "spend: 一成功一拒绝"
        ( Audit ((70, ["read"]), ["ok read -30 => 70", "reject shell cost 90 > 70"])
        )
        (spend 100 [("read", 30), ("shell", 90)])
    , checkEq
        "spend: 空列表"
        (Audit ((10, []), []) :: Audit (Int, [String]))
        (spend 10 [])
    , checkEq
        "spend: 预算刚好用完"
        (Audit ((0, ["a"]), ["ok a -10 => 0", "reject b cost 1 > 0"]))
        (spend 10 [("a", 10), ("b", 1)])
    ]
