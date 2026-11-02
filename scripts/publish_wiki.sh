#!/usr/bin/env bash
# 把本仓 `wiki/*.md` 同步到 GitHub Wiki。
#
# 前置：GitHub 要求在网页上**先创建第一页**（打开
#   https://github.com/bfxh/trit-parts/wiki → "Create the first page" → 标题 Home → 随便存）
# 之后 wiki 的 git 仓才存在，本脚本才能推。
#
# 用法：scripts/publish_wiki.sh [wiki 检出目录]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dst="${1:-$root/../trit-parts-wiki}"

if [ ! -d "$dst/.git" ]; then
  git clone git@github.com:bfxh/trit-parts.wiki.git "$dst"
fi

# README.md 是给仓库看的说明，不进 wiki
find "$root/wiki" -maxdepth 1 -name '*.md' ! -name 'README.md' -exec cp {} "$dst"/ \;

cd "$dst"
git add -A
if git diff --cached --quiet; then
  echo "wiki 已是最新"
  exit 0
fi
git commit -m "wiki: 同步 $(date +%F) 内容"
git push
echo "已推送：https://github.com/bfxh/trit-parts/wiki"
