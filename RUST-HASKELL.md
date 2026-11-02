# Rust ↔ Haskell 对照速查表

只收**写 agent 时会用到**的对应关系。左边是你会的，右边是要学的。

---

## 1. 类型

| Rust | Haskell | 备注 |
|---|---|---|
| `struct Foo { a: i32 }` | `data Foo = Foo { a :: Int }` | 单个构造子 |
| `enum E { A, B(i32) }` | `data E = A \| B Int` | 多个构造子，同构 |
| `struct A;` / `struct B(A);` | `newtype B = B A` | 零运行时开销，类型擦除 |
| `struct P(String)` | `newtype P = P String` | 防串味（Command vs Path） |
| `Option<T>` | `Maybe a` | `Some`→`Just`，`None`→`Nothing` |
| `Result<T, E>` | `Either e a` | **注意顺序：错误在前** |
| `()` | `()` | 一样 |
| `!` | `Void` | 永远不会返回 |
| `Vec<T>` | `[a]` | 链表，不是连续内存 |
| `&[T]` | `[a]` | 同样是切片习惯用法 |
| `String` / `&str` | `String` / `Text` | `String = [Char]`，慢；生产用 `text` |
| `HashMap<K,V>` | `Data.Map.Map k v` | 有序；无序用 `Data.HashMap` |
| `Box<T>` | 无 | 惰性 + GC，不需要显式装箱 |
| `Rc<RefCell<T>>` | `IORef` / `TVar` / 纯数据 | 不可变为主，共享状态是例外 |
| `i64` / `f64` | `Int` / `Double`（都是机器字） | 任意精度用 `Integer` |

**类型默认化（type defaulting）**：`5` 的类型是 `Num a => a`，编译器在没人约束时
会自动选 `Integer`/`Double` 并**警告**。看到 `-Wtype-defaults` 就补签名，
这是你 `test/test.hs` 里已经遇到过的。

---

## 2. 函数

```rust
// Rust
fn add(a: i32, b: i32) -> i32 { a + b }
let inc = |x| add(x, 1);
```

```haskell
-- Haskell
add :: Int -> Int -> Int
add a b = a + b

inc = add 1        -- 部分应用：不需要闭包,直接就是函数
```

| Rust | Haskell |
|---|---|
| `\|x\| expr` | `\x -> expr` |
| `impl Fn(i32) -> i32` | `Int -> Int` |
| 泛型 `<T: Trait>` | `Trait a =>`（写在签名前面） |
| `where` 从句 | `where` 子句（在定义**后面**） |
| `match x { ... }` | `case x of ...` 或函数多方程式 |
| 早返回 `return x;` | **没有**。`if` 是表达式，直接给值 |
| `for x in v { .. }` | `mapM_ f v` / `forM_ v f` |
| `while` / `loop` | 递归或 `foldr` / `until` |
| `?` | `do` 里的 `<-`，或直接 `>>=` |
| `x.await` | 完全是另一套（`async` 库），先别管 |

---

## 3. Trait ↔ 类型类

```rust
trait Tool {
    fn name(&self) -> String;
    fn cost_ms(&self) -> i64 { 100 }          // 默认方法
}
impl Tool for ReadTool { fn name(&self) -> String { "read".into() } }
fn expensive<T: Tool>(t: &T) -> bool { t.cost_ms() > 1000 }
```

```haskell
class Tool a where
  toolName   :: a -> String
  toolCostMs :: a -> Int
  toolCostMs _ = 100                          -- 默认方法

instance Tool ReadTool where
  toolName _ = "read"

expensive :: Tool a => a -> Bool
expensive t = toolCostMs t > 1000
```

三个必须知道的差异：

1. **没有 `self`**。方法就是普通函数，接收者是第一个参数。
2. **实例全局唯一**。一个类型对一个类只能有一个 `instance`，所以不需要
   `dyn Trait` 也知道调用哪个实现。反过来，你无法为同一个类型写两个
   "不同语义"的 `Tool` 实现（要用 newtype 包一层）——这一点和 Rust 相反。
3. **孤儿实例**。Rust 有 orphan rule 强制；Haskell 没有，GHC 只在
   `-Worphans` 下警告。实践上仍然应该把实例写在类型或类自己的模块里。

`impl Trait` 返回泛型 → `Tool a => a`。`dyn Trait` → 需要显式存在类型，
先别管，等你真需要异构工具列表时我们再用"和类型/ADT"的方式做（更 Haskell）。

---

## 4. Monad = 可组合的 `?`

这是全篇最重要的一张表。**你已经会 Monad 了**，只是不知道它叫这个名字。

```rust
fn run(args: &Args) -> Result<Out, Error> {
    let a = parse_a(args)?;        // 失败就整体失败
    let b = parse_b(args)?;
    Ok(combine(a, b))
}
```

```haskell
run :: Args -> Either Error Out
run args = do
  a <- parseA args               -- 失败就整体失败
  b <- parseB args
  pure (combine a b)
```

`>>=` 干的就是 `?` 干的活：**取出成功值，失败则短路**。区别是：

- Rust 的 `?` 是语法，写死在 `Try` 上；
- Haskell 的 `>>=` 是个**接口**，换成 `Maybe`、`[a]`（不确定/多结果）、
  `State`（带状态）、`IO`（带副作用）、你自己的 `Audit`（带日志）都成立。

所以 Rust 里你要为"带日志的失败链"手写一堆结构体 + 传播代码；
Haskell 里那是 `WriterT [String] (Either Error)`，一行类型。

```
do { x <- m;  rest }   ==   m >>= \x -> rest
do { m;       rest }   ==   m >> rest
do { let x = e; rest } ==   let x = e in rest
do { pure e }          ==   pure e
```

`do` 只有这四条规则。看懂了，`do` 就从"魔法"变成"缩写"。

### Functor / Applicative / Monad 一句话版

| 类 | 方法 | 含义 | Rust 对应 |
|---|---|---|---|
| `Functor` | `fmap` / `<$>` | 改里面的值，不改结构 | `.map()` |
| `Applicative` | `pure` / `<*>` | 两个独立的效果合并 | `.zip()` / 并行校验 |
| `Monad` | `>>=` | 后一步依赖前一步的结果 | `.and_then()` / `?` |

从下往上：`Monad` 最强，`Applicative` 可以并行，`Functor` 最弱。
**签名里约束越弱，能力越强**（能接受更多类型）——这是设计 API 的原则。

---

## 5. 词法小抄

| 符号 | 意思 |
|---|---|
| `f $ x` | `f x`，用来省括号：`putStrLn $ "a" ++ b` |
| `f . g` | 组合：`f (g x)`，等价 Rust `\|x\| f(g(x))` |
| `x <> y` | Semigroup 拼接（`String` 的 `++` 的泛化） |
| `x ++ y` | 列表拼接 |
| ``f `foo` x`` | 中缀调用：`foo f x` |
| `_` | 丢弃的绑定 |
| `a `seq` b` | 强制先求值 `a`（惰性下的"压住"） |
| `undefined` | 类型正确但一求值就炸，用来占位 |
| `\x -> e` | 闭包 |
| `--` | 行注释 |
| `{- -}` | 块注释 |

---

## 6. 会绊住你的三件事

1. **惰性求值**。"定义了但没求值"是合法的，所以没有 `dead_code` 警告；
   `undefined` 能通过类型检查，只在真正被用到时爆炸。想调试"到底跑没跑"，
   先看有没有东西逼它求值。
2. **没有 `return`**。`return` 在 Haskell 里是 `pure`，是"把值提升进 Monad"，
   不是"函数返回"。函数体最后一个表达式的值就是返回值。
3. **签名的类型参数是"输入"不是"输出"**。`f :: Maybe Int` 意味着 `f` 是
   一个 `Maybe Int` 的值，不是"返回 Maybe Int 的函数"。没有参数就没有 `()`。
