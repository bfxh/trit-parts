# wiki/ —— 知识库源文件

这里的 13 个 `.md` 是 GitHub Wiki 的正本（仓库里可读、可 review、可 diff）。

## 发布到 GitHub Wiki

GitHub 要求**先在网页上建第一页**，wiki 的 git 仓才会存在：

1. 打开 <https://github.com/bfxh/trit-parts/wiki>
2. 点 **Create the first page** → 标题填 `Home` → 内容随便写（会被覆盖）→ Save
3. 回到本机执行：

```bash
scripts/publish_wiki.sh
```

脚本会 clone `trit-parts.wiki.git`、把本目录的页面拷进去并推送。
之后每次改完 `wiki/` 重跑一次即可。

> 为什么不在仓库里直接生成 wiki：GitHub 没有创建 wiki 首页的 API，
> 首页必须由登录用户在网页上创建一次。

## 页面

| 文件 | Wiki 页 |
|---|---|
| `Home.md` | 首页（索引） |
| `三进制基础.md` | 三进制基础（trit-core） |
| `训练与量化.md` | 训练与量化（trit-learn） |
| `观感与风格.md` | 观感与风格（trit-look） |
| `部件分解-总览.md` | 部件分解 · 总览 |
| `部件分解-架构.md` | 部件分解 · 架构 |
| `部件分解-数据.md` | 部件分解 · 数据 |
| `部件分解-训练.md` | 部件分解 · 训练 |
| `部件分解-评测.md` | 部件分解 · 评测 |
| `部件分解-局限.md` | 部件分解 · 局限 |
| `生态其他库.md` | 生态其他库 |
| `工程门禁与复现.md` | 工程门禁与复现 |
| `数据生成.md` | 数据生成参数 |
| `CLI手册.md` | CLI 手册 |
| `踩坑清单.md` | 踩坑清单 |
| `术语表.md` | 术语表 |
