#!/usr/bin/env bash
# 用法:
#   ./run.sh                      # 列出所有练习
#   ./run.sh exercises/Ex01Adt.hs # 跑一个练习
#   ./run.sh solutions/Ex01Adt.hs # 跑参考答案
set -euo pipefail
cd "$(dirname "$0")"

if [[ $# -eq 0 ]]; then
  echo "用法: ./run.sh <文件.hs>"
  echo
  echo "练习:"
  ls exercises/*.hs 2>/dev/null | sed 's/^/  /'
  echo
  echo "参考答案:"
  ls solutions/*.hs 2>/dev/null | sed 's/^/  /'
  exit 1
fi

exec runghc -isrc -Wall "$@"
