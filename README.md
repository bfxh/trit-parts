# trit-parts

**三进制（{-1, 0, +1}）× 部件分解**：把**一张 RGB 照片**变成**带部件切分的 3D 网格**。
纯 Rust；训练、推理、网格、UV/图集全在本仓内，不依赖原 `trit` 单体仓。

> 状态：**研究原型，`publish = false`**。管线每一段都跑通并有实测读数，但深度精度还不足以支撑「可用的
> 3D 资产」——见下方[能力边界](#能力边界必须读)。

## 管线

```
RGB 一张
  ├─ 前景头        → 前景掩码            (前景 IoU 0.93–0.95)
  ├─ 部件边界头     → 边界图 → 分水岭 → 实例图 (部件 mIoU 0.458，pred/gt 0.94)
  └─ 卷积深度头     → 相对 log 深度        (8.11%，常数基线 9.01%)
        ↓ 反投影 + 体素填实 + surface nets
      单图 3D 网格（闭合）
        ↓ 按源视角实例图投影归属
      part_001.ply … part_NNN.ply
```

## 快速开始

```bash
# 构建（wgpu 后端需要 `gpu` feature）
cargo build --release --features gpu

# 1) 训练部件边界头（数据：见 scripts/s1_gen_scenes.py + blender_gt.py）
cargo run --release --features gpu --bin parts-train -- \
  --data <renders/scene0000,renders/scene0001,...> \
  --seg-sub pbnd --bnd-label 2 --bnd-weight 4 --steps 6000 --res 384 \
  --state runs/pb/state.bin

# 2) 导出部署包
cargo run --release --bin parts-cli -- export --state runs/pb/state.bin --out runs/pb/pb.tpm

# 3) 评测（默认工作点 = 留出集上选出的 margin −1 / min-size 50 / merge-weak 0）
cargo run --release --features gpu --bin parts-inst -- eval \
  --model runs/pb/pb.tpm --renders <renders> --scenes <scenes> \
  --gt part --boundary --k 5 --res 384

# 4) 单图 → 网格 → 逐部件 PLY（纯 RGB：前景/深度/实例都由模型出）
cargo run --release --features gpu --bin parts-depth -- mesh-single \
  --dcn runs/depth.dcn --fg runs/pb/pb.tpm --inst runs/inst/scene0050_000000.npy \
  --scene <scene> --frame 0 --cell 0.02 \
  --out out/mesh.ply --split-dir out/parts
```

## 模块

| 模块 | 作用 |
|---|---|
| `tconv`, `net`, `backward` | 三值卷积/全卷积网的 CPU+GPU 前反向、STE、量化 |
| `parts`, `inst` | 部件 id 编解码、边界图、连通域、分水岭、弱边界并块 |
| `mesh`, `atlas`, `uv` | 表面网、填实、清理、UV 展开（LSCM）、图集烘焙 |
| `tex` | 程序化材质、quilt 合成、风格预设（cel/oil/epic） |
| `depth`, `depthnet` | 线性深度头 / 小型卷积深度头 |
| `look`, `light` | 观感度量（转发 `trit-look`）、朗伯光照求解与重打光 |
| `splat`, `fuse`, `geo` | 高斯/点云融合与相机几何 |
| `matnet`, `ridge`, `ood` | 材质分类、岭回归、域外/取景闸门 |

## 实测读数（留出场景，2026-11）

| 项 | 读数 | 口径 |
|---|---|---|
| 前景 IoU | **0.977** | 模型前景头 vs GT seg（同模型） |
| 部件 mIoU | **0.490** | margin −1 / min-size 50 / merge-weak 0，80 帧（290 场景 × 35k 步）|
| 部件数 pred/gt | **0.84**（p90 1.27） | 同上；计数±1 30% |
| 深度相对误差 | **8.11%**（常数基线 9.01%） | 形状对齐，10 个留出场景 × 8 帧 |
| 单图网格 | 32k–43k 顶点、72k–100k 面、闭合 | 3 个留出场景 |
| 逐部件 PLY | 14 / 17 / 8 个部件 | GT ≈ 11 / 10 / 11 |

## 能力边界（必须读）

1. **深度 8.11% ⇒ 网格几何不可信**（5 m 物体误差 ≈ 0.4 m）。能看的只有拓扑与切分。
   五个杠杆（数据 6× / 感受野 / 多尺度输入 / 量化 / 多视角一致性）已全部否证：
   在「64² RGB + 3 层小卷积」框架下这条线到顶。
2. 密集簇**仍会过分割**（最坏帧 24 vs GT 10）。根因是边界头精确率 0.26，后处理只能压掉约四分之一。
3. 相机内参用数据集默认（35 mm/36 mm）；真实照片需标定或显式给默认假设。
4. 只对训练分布（程序化合成的部件簇）有效；真实照片属域外。

## 数据

`scripts/s1_gen_scenes.py`（程序化场景 + 材质标签）→ `scripts/blender_gt.py`（Blender 渲 RGB/深度/法线/分割 + 相机位姿）。
实测渲染 **3.3–5.0 s/场景**（8 帧 384²，GPU）。

## 许可

MIT OR Apache-2.0。
