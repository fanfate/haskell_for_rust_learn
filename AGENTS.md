# AGENTS.md

## 协作约定

- **任何 `git commit` / `git push` 前必须先得到我的明确同意。**
  改完代码只汇报「待提交」内容与 diff 摘要，等我回复 commit 再执行。
  （`git add`、`git status`、`git diff`、`git log` 等只读或暂存操作不受限制。）

## 本仓库的既定事实

- 日常跑练习不构建：`runghc -isrc -Wall <文件>`，`run.sh`（bash/WSL）与
  `run.ps1`（pwsh/Windows）都只是它的壳。别为练习引入 cabal 构建步骤。
- `run.ps1` 必须是 **UTF-8 with BOM**：Windows PowerShell 5.1 读无 BOM 的 UTF-8
  会把中文读成乱码；pwsh 7 对 BOM 无感，所以带 BOM 是两头都对的选择。
- 中文输出不要靠改 `chcp` 或 `[Console]::OutputEncoding` 解决：GHC 跟随控制台码页，
  `.ps1` 的中文由 PowerShell 现场转码，两者本来就一致；硬改反而会让另一侧乱码。
- 源文件统一 UTF-8（LF），`.hs` 不需要 BOM。
