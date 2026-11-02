{-# OPTIONS_GHC -Wall #-}

-- | 阶段 1：代数数据类型（ADT）与模式匹配
--
-- Rust 对照：
--   * @data@ 有多个构造子  -> @enum@
--   * @data@ 只有一个构造子 + 具名字段 -> @struct@
--   * @newtype@ -> @struct Foo(T)@ 的零开销版本（编译期擦除，运行时无包装）
--   * 模式匹配 -> @match@，但 Haskell 里它是"表达式"，可以嵌在任意位置；
--     漏掉构造子会给出 @-Wincomplete-patterns@ 警告（-Wall 已开启）
--
-- 本阶段的核心思想：让非法状态无法被构造出来。
module Main (main) where

import Spec (check, checkEq, runChecks)

-- ============================================================
-- 1. 一个工具调用长什么样
-- ============================================================

-- Rust 里你会写：
--   enum ToolCall {
--       ReadFile { path: String },
--       WriteFile { path: String, contents: String },
--       Shell { command: String, timeout_ms: i64 },
--       Noop,
--   }
--
-- 坑：ReadFile 和 WriteFile 共用了 path 字段，于是自动生成的
--   path :: ToolCall -> FilePath
-- 是一个 **偏函数** —— 对 Shell / Noop 调用它会在运行时报错。
-- 所以下面宁可老实写模式匹配，也不用字段选择器。
data ToolCall
  = ReadFile {path :: FilePath}
  | WriteFile {path :: FilePath, contents :: String}
  | Shell {command :: String, timeoutMs :: Int}
  | Noop
  deriving (Eq, Show)

-- TODO 1：逐个构造子匹配。期望结果：
--   ReadFile p    -> "read "  <> p
--   WriteFile p _ -> "write " <> p
--   Shell c _     -> "shell: " <> c
--   Noop          -> "noop"
describe :: ToolCall -> String
describe call = case call of
  ReadFile p -> "read " <> p
  WriteFile p _ -> "write " <> p
  Shell c _ -> "shell: " <> c
  Noop -> "noop"

-- TODO 2：只有"会改外部世界"的调用需要人工审批：WriteFile 和 Shell。
-- 提示：先故意漏掉一个构造子，看看编译器的 -Wincomplete-patterns 警告长什么样。
needsApproval :: ToolCall -> Bool
needsApproval call = case call of
  ReadFile _ -> False
  WriteFile _ _ -> True
  Shell _ _ -> True
  Noop -> False

-- TODO 3：所有 Shell 调用的超时之和。
-- 请用 foldr（或列表推导），不要写显式递归 —— 体会"用折叠代替循环"。
totalTimeoutMs :: [ToolCall] -> Int
totalTimeoutMs =
  foldr
    ( \call acc -> case call of
        Shell _ t -> t + acc
        _ -> acc
    )
    0

-- ============================================================
-- 2. newtype：用类型区分"底层表示相同、含义不同"的东西
-- ============================================================

-- Rust 里你会写 struct Path(String) / struct Command(String)，
-- 这样编译器不会让你把 Command 传进需要 Path 的地方。
-- Haskell 的 newtype 在运行时零开销：Path "a" 和 "a" 是同一个东西。
newtype Path = Path FilePath
  deriving (Eq, Show)

newtype Command = Command String
  deriving (Eq, Show)

-- TODO 4：把 Command 包成一次 Shell 调用，超时固定 5000ms。
bashTool :: Command -> ToolCall
bashTool (Command c) = Shell c 5000

-- 反过来：从 ToolCall 里安全地取出路径（可能是 Nothing）。
-- 注意这里返回 Maybe，和 Rust 的 Option 完全一致。
callPath :: ToolCall -> Maybe Path
callPath call = case call of
  ReadFile p -> Just (Path p)
  WriteFile p _ -> Just (Path p)
  _ -> Nothing

-- ============================================================
-- 3. 状态机：把"待审批的工具"塞进它该在的状态里
-- ============================================================

-- 对比两种设计：
--   A. data Phase = Planning | Acting | WaitingApproval | Finished
--      data AgentState = AgentState Phase Int (Maybe ToolCall)
--      -> 非 WaitingApproval 的状态也可能带着 ToolCall，非法状态可表示 ❌
--
--   B. data Phase = ... | WaitingApproval ToolCall
--      -> 只有等待审批时才能拿到待审批的调用，其他状态根本拿不到 ✅
--
-- 这就是 "make illegal states unrepresentable"，Rust 里同样适用，
-- 而且 Rust 的 enum 也能这么写。差别在于 Haskell 强制你处理每一个分支。
data Phase
  = Planning
  | Acting
  | WaitingApproval ToolCall
  | Finished
  deriving (Eq, Show)

data AgentState = AgentState
  { phase :: Phase
  , steps :: Int
  }
  deriving (Eq, Show)

-- TODO 5：状态转移（除 Finished 外，steps 都 +1）
--   Planning          + 任意调用 c  -> Acting
--   Acting            + Noop        -> Finished
--   Acting            + 其他调用 c  -> WaitingApproval c
--   WaitingApproval _ + 任意调用    -> Acting
--   Finished          + 任意调用    -> 原样返回（什么都不做）
step :: AgentState -> ToolCall -> AgentState
step state call = case phase state of
  Planning -> state {phase = Acting, steps = steps state + 1}
  Acting -> case call of
    Noop -> state {phase = Finished, steps = steps state + 1}
    c -> state {phase = WaitingApproval c, steps = steps state + 1}
  WaitingApproval _ -> state {phase = Acting, steps = steps state + 1}
  Finished -> state

-- ============================================================
-- 测试（不要改这里）
-- ============================================================

main :: IO ()
main =
  runChecks
    [ checkEq "describe (ReadFile)" "read notes.md" (describe (ReadFile "notes.md"))
    , checkEq "describe (WriteFile)" "write notes.md" (describe (WriteFile "notes.md" "hi"))
    , checkEq "describe (Shell)" "shell: ls -la" (describe (Shell "ls -la" 1000))
    , checkEq "describe (Noop)" "noop" (describe Noop)
    , checkEq "needsApproval (WriteFile)" True (needsApproval (WriteFile "a" "b"))
    , checkEq "needsApproval (ReadFile)" False (needsApproval (ReadFile "a"))
    , checkEq "needsApproval (Noop)" False (needsApproval Noop)
    , check "所有 Shell 调用都要审批" (all needsApproval [Shell "a" 1, Shell "b" 2])
    , checkEq
        "totalTimeoutMs"
        7000
        (totalTimeoutMs [ReadFile "a", Shell "ls" 5000, Shell "make" 2000, Noop])
    , checkEq "totalTimeoutMs []" 0 (totalTimeoutMs [])
    , checkEq "bashTool" (Shell "ls -la" 5000) (bashTool (Command "ls -la"))
    , checkEq "callPath (ReadFile)" (Just (Path "a.md")) (callPath (ReadFile "a.md"))
    , checkEq "callPath (Shell)" Nothing (callPath (Shell "ls" 1))
    , checkEq
        "step: Planning -> Acting"
        (AgentState Acting 1)
        (step (AgentState Planning 0) (ReadFile "a"))
    , checkEq
        "step: Acting + Noop -> Finished"
        (AgentState Finished 2)
        (step (AgentState Acting 1) Noop)
    , checkEq
        "step: Acting + Shell -> WaitingApproval"
        (AgentState (WaitingApproval (Shell "rm -rf /" 0)) 2)
        (step (AgentState Acting 1) (Shell "rm -rf /" 0))
    , checkEq
        "step: WaitingApproval -> Acting"
        (AgentState Acting 3)
        (step (AgentState (WaitingApproval (Shell "rm -rf /" 0)) 2) Noop)
    , checkEq
        "step: Finished 吸收一切"
        (AgentState Finished 4)
        (step (AgentState Finished 4) (Shell "ls" 1))
    ]
