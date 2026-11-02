# learn-haskell

面向**有 Rust 基础、正在用 Rust 写 agent、没学过 Haskell** 的学习集。

目标不是"学会 Haskell 写项目"，而是**把函数式的东西偷回 Rust**。
所以练习全部围绕 agent 的建模问题：工具调用、状态机、参数校验、
预算、可测试的副作用。

---

## 怎么跑

```bash
./run.sh                                   # 列出所有练习
./run.sh exercises/Ex01Adt.hs              # 跑一个练习
./run.sh solutions/Ex01Adt.hs              # 看参考答案（做完再对）
```

`run.sh` 就是 `runghc -isrc -Wall`，改完存盘直接重跑，没有构建步骤。
`-Wall` 一直开着——Haskell 的编译器警告质量极高，当作老师用。

也可以进交互环境：

```bash
ghci -isrc exercises/Ex01Adt.hs
# ghci> :t describe
# ghci> describe (ReadFile "a.md")
```

`:t` 在 Haskell 里不是可选操作，是主要的探索手段。

---

## 目录

```
.
├── run.sh                 # 练习运行器
├── RUST-HASKELL.md        # 对照速查表：同一个东西两边怎么写
├── src/Spec.hs            # 迷你测试框架（只依赖 base）
├── exercises/             # 练习：函数体是 undefined，注释里写清了要什么
├── solutions/             # 参考答案
└── test/test.hs           # 最初那个 Hello World，留作起点纪念
```

---

## 学习法

1. 打开练习文件，读 `TODO` 上面的注释（那里才是真正的内容）。
2. 改代码，`./run.sh <文件>`。
3. 失败信息会给出「期望 / 实际」，对着调。写不出来就先看 `solutions/`，
   但**看完关掉再默写一遍** —— Haskell 的语法密度高，看会 ≠ 写会。
4. 遇到警告别忽略。`-Wincomplete-patterns` 和 `-Wtype-defaults` 是最常
   出现的两条，都指向真实的设计问题。

---

## 路线图

| 阶段 | 主题 | 练习 | 状态 |
|---|---|---|---|
| 1 | ADT、模式匹配、`newtype`、状态机 | `exercises/Ex01Adt.hs` | ✅ 可做 |
| 2 | `Maybe` / `Either`、`traverse`、`?` 的对应物 | `exercises/Ex02MaybeEither.hs` | ✅ 可做 |
| 3 | 类型类（trait）、`Functor`/`Applicative`/`Monad`、`do` 记法 | `exercises/Ex03Typeclass.hs` | ✅ 可做 |
| 4 | `State` / `Reader` / `Except`：把 agent 的依赖和状态编码进类型 | 待出 | ⬜ |
| 5 | **Effect + interpreter**：把 LLM 调用/工具调用变成数据，可回放可测试 | 待出 | ⬜ |
| 6 | Parser combinator：解析 tool call 参数、流式输出拼装 | 待出 | ⬜ |
| 7 | 惰性求值与无限流：trace、事件流、提前终止 | 待出 | ⬜ |
| 终局 | `mini-agent/`：可替换解释器的小 agent | 待出 | ⬜ |

### 暂时跳过的东西

Template Haskell、lens、type family、GADT、各种 `{-# LANGUAGE #-}` 扩展、
cabal 打包细节、范畴论。这些会吃掉 80% 的时间，带来的 agent 相关收益接近 0。
（阶段 5 的 effect 系统做完之后，再回头看 GADT 会顺很多。）

---

## 和 Rust 的心智模型差异（三条最容易踩的）

1. **惰性求值**。"定义了但没被求值"是常态，所以没有 `dead_code` 警告，
   也所以 `undefined` 能通过类型检查、只在被用到时炸。调试时先怀疑
   "这段代码到底跑没跑"。
2. **没有 `self`**。类型类方法就是普通函数，函数就是值，值可以部分应用
   （`powerOfX 2` 就是一个"已经注入 2 的函数"）。Rust 里要闭包+移动语义
   才能做到的事，这里是默认行为。
3. **签名先行**。写 Haskell 的顺序是：先写 `::`，再写实现，让类型推着你走。
   这也是它最适合"先把架构想清楚"的原因。

更细的对照见 `RUST-HASKELL.md`。
