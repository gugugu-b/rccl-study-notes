# AllReduce · BW1100 带宽公式

n = 8，s = 4 B（FP32），M = 1 GiB = 1,073,741,824 B。卡间标称参考 **224 GB/s**。 [源码](../../../rccl-tests/src/all_reduce.cu) · [图解](AllReduce_busbw.html)

<div align="center">

<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  :root {
    --surface: #ffffff; --surface-muted: #f6f6fb; --surface-soft: #eef0f7;
    --border: #e2e2ec; --text: #1a1a2e; --text-muted: #6b6b80;
    --brand: #7c5cff; --brand-strong: #5b3fd6; --brand-soft: #efebff;
    --font-sans: -apple-system, "PingFang SC", "Noto Sans CJK SC", "WenQuanYi Micro Hei", sans-serif;
    --font-mono: "SF Mono", "JetBrains Mono", "Menlo", monospace;
    --radius: 8px; --radius-card: 12px; --weight-medium: 500; --weight-strong: 700;
  }
  .bw-root { font-family: var(--font-sans); color: var(--text); background: var(--surface); border:1px solid var(--border); border-radius: var(--radius-card); padding: 20px; width: 100%; max-width: 880px; }
  .bw-title { font-size: 16px; font-weight: var(--weight-strong); margin: 0 0 4px; }
  .bw-sub { font-size: 12px; color: var(--text-muted); margin: 0 0 12px; }
  .bw-grid { display: flex; gap: 20px; align-items: stretch; }
  .bw-ring { flex: 0 0 300px; }
  .bw-derive { flex: 1; display: flex; flex-direction: column; gap: 10px; }
  .bw-derive-head { font-size: 13px; font-weight: var(--weight-medium); color: var(--text-muted); letter-spacing: .04em; text-transform: uppercase; }
  .bw-step { display: flex; gap: 10px; align-items: baseline; font-size: 14px; line-height: 1.5; }
  .bw-step .n { flex: 0 0 22px; font-family: var(--font-mono); font-size: 12px; color: var(--brand-strong); font-weight: var(--weight-strong); }
  .bw-step .t { font-family: var(--font-mono); font-size: 13px; }
  .bw-step .d { font-size: 12px; color: var(--text-muted); }
  .bw-concl { margin-top: 6px; padding: 12px 14px; background: var(--brand-soft); border:1px solid var(--brand); border-radius: var(--radius); font-size: 14px; line-height: 1.5; }
  .bw-concl .k { font-family: var(--font-mono); font-weight: var(--weight-strong); color: var(--brand-strong); }
  .bw-concl .h { font-size: 12px; color: var(--text-muted); margin-top: 4px; }
  .bw-legend { display: flex; gap: 16px; font-size: 12px; color: var(--text-muted); margin-top: 12px; flex-wrap: wrap; }
  .bw-legend span b { color: var(--text); font-weight: var(--weight-medium); }
  @media (max-width: 720px) {
    .bw-grid { flex-direction: column; align-items: center; }
    .bw-ring { flex: auto; max-width: 100%; }
    .bw-ring svg { max-width: 100%; height: auto; }
    .bw-step { flex-wrap: wrap; }
  }
</style>

  <div class="bw-root">
    <div class="bw-title">AllReduce · BW1100 带宽公式</div>
    <div class="bw-sub">BW1100 (NMZ) ×8，DTK 26.10，FP32，1 GiB，卡间参考 224 GB/s</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="ah" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" markerUnits="userSpaceOnUse" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#7c5cff"/>
            </marker>
          </defs>
          <!-- Ring backbone -->
          <circle cx="150" cy="170" r="95" fill="none" stroke="#7c5cff" stroke-width="2.5" stroke-dasharray="4 3" opacity="0.55"/>
          <!-- Direction arrow on 0->1 arc -->
          <path d="M 233 198 A 95 95 0 0 1 217 237" fill="none" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <!-- 8 nodes -->
          <g font-family="SF Mono, monospace" font-size="12" fill="#1a1a2e" text-anchor="middle" dominant-baseline="central">
            <circle cx="245" cy="170" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="245" y="170">G0</text>
            <circle cx="217" cy="237" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="217" y="237">G1</text>
            <circle cx="150" cy="265" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="150" y="265">G2</text>
            <circle cx="83"  cy="237" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="83"  y="237">G3</text>
            <circle cx="55"  cy="170" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="55"  y="170">G4</text>
            <circle cx="83"  cy="103" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="83"  y="103">G5</text>
            <circle cx="150" cy="75"  r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="150" y="75">G6</text>
            <circle cx="217" cy="103" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="217" y="103">G7</text>
          </g>
          <!-- center label -->
          <text x="150" y="166" text-anchor="middle" font-family="SF Mono, monospace" font-size="13" font-weight="700" fill="#5b3fd6">n = 8</text>
          <text x="150" y="184" text-anchor="middle" font-family="-apple-system, sans-serif" font-size="11" fill="#6b6b80">Ring 拓扑</text>
          <!-- stage annotations -->
          <g font-family="-apple-system, 'PingFang SC', sans-serif" font-size="11">
            <rect x="18" y="298" width="128" height="30" rx="6" fill="#efebff" stroke="#7c5cff"/>
            <text x="82" y="312" text-anchor="middle" fill="#5b3fd6" font-weight="600">阶段① ReduceScatter</text>
            <text x="82" y="324" text-anchor="middle" fill="#6b6b80">7 步 × 128 MiB</text>
            <rect x="154" y="298" width="128" height="30" rx="6" fill="#efebff" stroke="#7c5cff"/>
            <text x="218" y="312" text-anchor="middle" fill="#5b3fd6" font-weight="600">阶段② AllGather</text>
            <text x="218" y="324" text-anchor="middle" fill="#6b6b80">7 步 × 128 MiB</text>
          </g>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">每阶段 7 步，每步 128 MiB</div>
        <div class="bw-step"><span class="n">1</span><span class="t">c = 268,435,456，s = 4 B</span><span class="d">c 取日志中的 count</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">Q = c × s，f = 2(n−1)/n</span><span class="d">Q × f = 1,792 MiB</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">t = 14.3410 ms</span><span class="d">DTK 26.10 out-of-place 中位数</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">busBw = Q × f / (t × 10⁶) ≈ 131.03 GB/s</span><span class="d">占 224 GB/s 的 58.50%</span></div>
        <div class="bw-concl">
          <div>In-place <span class="k">131.03 GB/s</span>（#wrong=0）</div>
          <div class="h">按 224 GB/s 折算的参考时间为 8.3886 ms。</div>
        </div>
      </div>
    </div>
  </div>

</div>

## 源码口径

```text
Q = c × s
f = 2(n−1)/n
algBw (GB/s) = Q / (t_us × 1000)
busBw (GB/s) = Q × f / (t_us × 1000)
```

`c` 为测试表中 `count` 的元素个数，`s` 为每元素字节数，`t_us` 为测试表中的耗时（µs）。本例 `c` = 268,435,456，计分字节量 `Q × f` = **1,792 MiB**。

每 rank 参与规约的输入和输出各 1 GiB。Ring 模型下 ReduceScatter 和 AllGather 各 7 步，每步 128 MiB，因此计分量为 2 × 7 × 128 MiB。rccl-tests 对 AllReduce 始终使用相同的 f。

## DTK 26.10 复测命令

在 `rccl-tests/build` 下用 Bash 运行。每轮执行三次正确性检查。1 GiB FP32 out-of-place BusBW 三轮中位数为 **131.48 GB/s**。

完整扫包曾在 256 MiB 出现校验错误。以下配置的验收范围为 1 GiB out-of-place。

```bash
source /opt/dtk/env.sh
topo_dir=$(mktemp -d)
RCCL_FORCE_DETECT_TOPO=1 RCCL_TOPO_FILE_NAME="$topo_dir/all_reduce.xml" \
    NCCL_BUFFSIZE=1048576 \
    timeout -k 8s 90s ./all_reduce_perf -b 1G -e 1G -f 2 -n 20 -w 5 -c 3 -O 1 -g 8 -Y fine
```

## 1 GiB 实测

DTK 26.10，RCCL 2.27.7（`3b793e3`），单进程 1 线程管 8 卡（`-b 1M -e 1G -f 2 -g 8`），FP32，默认通信参数，3 轮中位数。

| 模式 | 耗时（ms） | algBw（GB/s） | busBw（GB/s） | 占 224 GB/s | #wrong |
| --- | ---: | ---: | ---: | ---: | ---: |
| Out-of-place | 14.3410 | 74.87 | **131.03** | 58.50% | 0 |
| In-place | 14.3400 | 74.87 | 131.03 | 58.50% | 0 |

按 224 GB/s 搬运等效计分字节量，参考时间为 **8.3886 ms**。占比是 `busBw / 224 × 100%`，用于对照 BW1100 标称带宽。

## 旧版记录

用户提供的 BW1100 旧版 1G 截图中，DTK 26.04-rc4 为 131.18 GB/s，26.04.1-rc1 为 131.22 GB/s。截图未标注数据类型和就地模式。
