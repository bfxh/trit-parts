# CLI 手册

10 个二进制，按用途分组。所有命令都是 `cargo run --release --features gpu --bin <bin> -- <子命令> ...`
（下文的 `parts-*` 指已构建的二进制）。

## 1. 数据

```bash
# 程序化场景（每场景 parts.json + objects.json）
python scripts/s1_gen_scenes.py --out data/scenes --scenes 240 --seed 23

# Blender 渲染（RGB / 深度 / 法线 / 分割 / 相机）
blender -b --factory-startup -P scripts/blender_gt.py -- \
  --out data/renders/pt0000 --objects-json data/scenes/pt0000/objects.json \
  --frames 8 --res 384 --samples 16 --device GPU

# 按参考集的相机分布重渲（修域偏移）
python scripts/rerender_matched.py --root data
```

## 2. 分割（`parts-inst` / `parts-train` / `parts-cli`）

```bash
# 生成部件边界标签（0 背景 / 1 内部 / 2 边界）
parts-inst prep --renders data/renders --scenes data/scenes --part-bnd

# 训练部件头（注意 --bnd-label 2）
parts-train --data <renders...> --seg-sub pbnd --bnd-label 2 --bnd-weight 4 \
  --steps 35000 --lr 1e-3 --lr-final 1e-4 --accum 4 --res 384 \
  --state runs/pb/state.bin

# 导出部署包（只有 export 出来才是 TPM1）
parts-cli export --state runs/pb/state.bin --out runs/pb/pb.tpm

# 评测（默认工作点 margin −1 / min-size 50 / merge-weak 0）
parts-inst eval --model runs/pb/pb.tpm --renders R --scenes S \
  --gt part --boundary --k 5 --res 384 [--dump outdir --dump-n 8]

# 一条龙：2D + 全帧 3D 部件 IoU + 前 3 场景分片
RENDERS=R SCENES=S HOLD=scene0050,scene0051 DCN=D bash scripts/eval_boundary.sh runs/pb/pb.tpm tag
```

`eval` 的常用旋钮：`--bnd-margin`（边界阈值，默认 −1）、`--min-size`（默认 50）、
`--merge-weak`（弱边界并块，默认 0）、`--merge-ratio/--merge-max`（面积并块，负结果，默认 0）。

## 3. 深度（`parts-depth`）

```bash
# 跨场景相对深度头（整图 64²、逐图归一化、可多尺度/多视角）
parts-depth cnn-train --data <renders...> --holdout a,b --size 64 --epochs 60 \
  --hidden 32 --dil 2 --stride 1 --full --f32 \
  [--pyr 1] [--mv-weight 1 --pair-gap 1 --mv-tau 0.5] --out runs/depth.dcn

# 用已存模型在同一留出集上评估（不训练）
parts-depth cnn-train --eval-only runs/depth.dcn --data <holdout> --holdout <同> --size 64 --stride 1 --full

# 深度 → 3D 点云体素 IoU（绝对尺度 / 中位尺度对齐）
parts-depth depth-iou --dcn runs/depth.dcn --scene S --frame 0 --cell 0.02

# 单图 → 网格 → 逐部件 PLY（纯 RGB：前景/深度/实例都由模型出）
parts-depth mesh-single --dcn runs/depth.dcn --fg runs/pb/pb.tpm \
  --inst out/inst/scene0050_000000.npy --scene S --frame 0 --cell 0.02 \
  --out out/mesh.ply --split-dir out/parts [--min-tris 10]

# 隔离分割的 3D 质量（两侧 GT 深度、只有归属不同）
parts-depth part-iou --scene S --frame 0 --inst out/inst/scene0050_000000.npy --cell 0.02
```

## 4. 重建与 3D（`parts-3d`）

| 命令 | 用途 |
|---|---|
| `infer` / `infer-ids` | 部件 id 推理（后者只出 id 图） |
| `eval` | 逐部件 3D IoU 评估（`--3d`） |
| `cloud` / `mesh` / `fuse` | 点云、单帧网格、多视图融合 |
| `splat` / `occ` / `align` / `obs-split` | 高斯泼溅、占据栅格、对齐、观测切分 |
| `occl-stats` | 遮挡/互穿统计 |

## 5. 纹理与观感

```bash
parts-3d mesh-tex ... --tex in.ppm [--atlas 512] [--lscm] [--texels 1.0] [--light-out side.json]
parts-3d tex-quilt --src in.png --out out.ppm --size 512 --patch 16   # 非参数合成
parts-3d tex-stylize --tex in.ppm --preset oil --strength 0.8 --out out.ppm
parts-3d tex --kind wood --size 256 --out wood.ppm                  # 程序化贴图
parts-3d look <img...>                                             # 观感指标
```

## 6. 材质与光照

```bash
parts-3d material-data --scene S --frames 0,1,2 --out csv
parts-3d material-fit --csv csv --out model.json [--test-csv held.csv]
parts-3d material-predict --model model.json --scene S --out pred.csv
parts-3d light-fit --scene S --frame 0            # 朗伯求解（方向/强度/环境）
parts-3d light-relight-normals --scene S --frame 0 --delta-deg 90
parts-3d light-est <img>                          # 图像代理量（已否证，仅对照）
```

## 7. 工具

```bash
parts-guard ...    # 训练看门狗（状态文件 + 响铃）
parts-ood ...      # 域外/取景闸门
parts-cli infer    # 单图推理（无 GPU 也可跑导出包）
parts-parity / parts-gradcheck / parts-bench   # 对拍/梯度检查/基准
```

## 8. 作业文件

`--job <json>` 把参数写进 JSON（未知键 fail-closed 并给最近键建议），例如 `jobs/example.json`。
