# 架构

## 1. 三进制表示

权重是 `{-1, 0, +1}` 的**量化值** `q`，每个输出通道一个可学 `scale`，有效权重 `E = q · scale`。
训练保留 f32 **latent** `w`，前向用 `q = round(w/scale).clamp(-1,1)`，反向用 STE 把对 `q` 的梯度换成对 `w` 的梯度：

| STE | 门函数 |
|---|---|
| `Identity` | 恒 1（经典 STE） |
| `Clipped { ratio }` | `|w/scale| ≤ ratio ? 1 : 0`（已饱和不再动） |
| `Soft` | `max(0, 1 − (w/scale)²)`（边界连续） |

实现在 `src/ste.rs`（本仓自带，不再依赖 `trit-learn`）。输出层与 bias 保持 f32——三值只有 ±1，
缺每通道 scale 调不出斜率。

## 2. 数据流

```
renders/<scene>/{rgb,depth,seg,normal,meta}
        │
        ├─ parts-inst prep --part-bnd ──► pbnd/（0 背景 / 1 内部 / 2 边界）
        │
        ├─ parts-train --seg-sub pbnd ──► state.bin（TPNT3）
        │        └─ parts-cli export ──► *.tpm（TPM1 部署包：只含 q/scale/γ/β/bias）
        │
        └─ parts-inst eval --boundary ──► 2D 实例图（可 --dump）
                 │
parts-depth cnn-train ──► *.dcn（DCN3：三层卷积 + med/iqr/out_b/dil）
                 │
                 └─ mesh-single --dcn --fg --inst
                        ├─ 深度 → 反投影点云
                        ├─ 体素 fill_solid → surface_nets → mesh.clean
                        └─ 顶点投回实例图 → 面多数票 → part_*.ply
```

## 3. 模型

### 3.1 部件头（边界 + 前景）
- 全卷积栈（13 层）`Net`，输出 `k·3 + 1` 通道：`k` 位三进制 id 的 logits + 前景（valid）。
- **监督的是边界图，不是 id**：`pbnd` 的 id 2 → 最后一位 digit 的 `+1`，id 1（内部）→ `0`。
- 稀疏类加权 `--bnd-label 2 --bnd-weight w`：边界只占前景 ~4–16%，普通 CE 一个点都不预测。
- 推理：前景 = `logits[k·3] > 0`；边界 = `logits[(k−1)·3+1] − logits[(k−1)·3] > margin`。
- 后处理：`split_by_boundary_min`（分水岭）→ `merge_weak`（共享边界平均间隔 < τ 的并块）。

### 3.2 深度头
- `conv(3·(1+pyr)→H) → ReLU → conv(H→H) → ReLU → conv(H→1)`，可膨胀（`--dil`）、可多尺度输入（`--pyr`）。
- 监督：逐图归一化的 log 深度（`(ln d − med)/iqr`，裁 ±4），L2；外置输出偏置 `out_b`
  （Conv 的 bias 在 scale 乘法之内，学全局 DC 会把 scale 压到 0）。
- 可选多视角一致性：相邻视角的预测投回本视角当目标（stop-gradient），Cauchy 软权重抑制遮挡。

## 4. 几何

- `geo::Camera`：`K` + `T_cw`（world→camera）；`unproject` 约定 Blender 相机看 −Z、+Y 朝上。
- 单图重建：前景像素反投影 → 体素 `Grid` → `fill_solid`（闭合背面）→ `surface_nets` → `mesh::clean`。
- UV/图集：法线聚类分 chart → 每 chart LSCM（Cauchy–Riemann + CGNR）→ 货架打包 → 逐 chart 烘焙。
- 分片：顶点投回源视角相机，取最近像素实例 id；面取三顶点多数票；按 id 重映射写 PLY。

## 5. 门与可复现

- 单测 **133 条**（`cargo test --features gpu`）。
- `scripts/mutation_check.py`（在单体仓里）对 `depthnet`/`inst` 的 5 条关键规则做单点变异，
  每条都有判决性单测抓住。
- 权重格式全部文本、逐位可复现（`TPM1` / `TPC7` / `DCN3` / `TPNT3`）。
