# AllGather · BW1100 带宽公式

n = 8，s = 4 B（FP32），M = 1 GiB = 1,073,741,824 B。卡间标称参考 **224 GB/s**。 [源码](../../../rccl-tests/src/all_gather.cu) · [图解](AllGather_busbw.html)

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
  .bw-src { font-family: var(--font-mono); font-size: 11px; color: var(--text-muted); background: var(--surface-muted); padding: 7px 10px; border-radius: var(--radius); margin: 0 0 16px; line-height: 1.5; }
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
    <div class="bw-title">AllGather · BW1100 带宽公式</div>
    <div class="bw-sub">BW1100 (NMZ) ×8，DTK 26.10，FP32，1 GiB，卡间参考 224 GB/s</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="ah" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" markerUnits="userSpaceOnUse" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#7c5cff"/>
            </marker>
          </defs>
          <!-- 环形顺时针 G0->G1->G2->G3->G4->G5->G6->G7->G0 -->
          <line x1="238.1" y1="186.6" x2="224.1" y2="220.6" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="200.6" y1="244.1" x2="166.6" y2="258.1" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="133.4" y1="258.1" x2="99.4"  y2="244.1" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="75.9"  y1="220.6" x2="61.9"  y2="186.6" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="61.9"  y1="153.4" x2="75.9"  y2="119.4" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="99.4"  y1="95.9"  x2="133.4" y2="81.9"  stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="166.6" y1="81.9"  x2="200.6" y2="95.9"  stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="224.1" y1="119.4" x2="238.1" y2="153.4" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <!-- 节点（G0 高亮：贡献段） -->
          <g font-family="SF Mono, monospace" font-size="12" fill="#1a1a2e" text-anchor="middle" dominant-baseline="central">
            <circle cx="245" cy="170" r="18" stroke="#7c5cff" fill="#efebff" stroke-width="2"/><text x="245" y="170">G0</text>
            <circle cx="217" cy="237" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="217" y="237">G1</text>
            <circle cx="150" cy="265" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="150" y="265">G2</text>
            <circle cx="83"  cy="237" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="83"  y="237">G3</text>
            <circle cx="55"  cy="170" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="55"  y="170">G4</text>
            <circle cx="83"  cy="103" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="83"  y="103">G5</text>
            <circle cx="150" cy="75"  r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="150" y="75">G6</text>
            <circle cx="217" cy="103" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="217" y="103">G7</text>
          </g>
          <!-- 底部阶段标注 -->
          <rect x="65" y="298" width="170" height="30" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
          <text x="150" y="313" text-anchor="middle" dominant-baseline="central" font-family="SF Mono, monospace" font-size="10" fill="#1a1a2e">单阶段 AllGather · 7 步 × 128 MiB</text>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">单卡贡献 128 MiB</div>
        <div class="bw-step"><span class="n">1</span><span class="t">c = 33,554,432，s = 4 B</span><span class="d">c 取日志中的 count</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">Q = n × c × s，f = (n−1)/n</span><span class="d">Q × f = 896 MiB</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">t = 7.2889 ms</span><span class="d">DTK 26.10 out-of-place 中位数</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">busBw = Q × f / (t × 10⁶) ≈ 128.90 GB/s</span><span class="d">占 224 GB/s 的 57.54%</span></div>
        <div class="bw-concl">
          <div>In-place <span class="k">128.99 GB/s</span>（#wrong=0）</div>
          <div class="h">按 224 GB/s 折算的参考时间为 4.1943 ms。</div>
        </div>
      </div>
    </div>
  </div>

</div>

## 源码口径

```text
Q = n × c × s
f = (n−1)/n
algBw (GB/s) = Q / (t_us × 1000)
busBw (GB/s) = Q × f / (t_us × 1000)
```

`c` 为测试表中 `count` 的元素个数，`s` 为每元素字节数，`t_us` 为测试表中的耗时（µs）。本例 `c` = 33,554,432，计分字节量 `Q × f` = **896 MiB**。

每 rank 贡献 128 MiB，最后持有 1 GiB。Ring 模型中每 rank 每个方向转发或接收 7 份分片，计分字节量为 896 MiB。

## DTK 26.10 复测命令

在 `rccl-tests/build` 下用 Bash 运行。覆盖 1 MiB 至 1 GiB 的完整扫包。1 GiB FP32 out-of-place BusBW 三轮中位数为 **130.18 GB/s**。

```bash
source /opt/dtk/env.sh
topo_dir=$(mktemp -d)
RCCL_FORCE_DETECT_TOPO=1 RCCL_TOPO_FILE_NAME="$topo_dir/all_gather.xml" \
    NCCL_BUFFSIZE=524288 \
    timeout -k 8s 90s ./all_gather_perf -b 1M -e 1G -f 2 -g 8
```

## 1 GiB 实测

DTK 26.10，RCCL 2.27.7（`3b793e3`），单进程 1 线程管 8 卡（`-b 1M -e 1G -f 2 -g 8`），FP32，默认通信参数，3 轮中位数。

| 模式 | 耗时（ms） | algBw（GB/s） | busBw（GB/s） | 占 224 GB/s | #wrong |
| --- | ---: | ---: | ---: | ---: | ---: |
| Out-of-place | 7.2889 | 147.31 | **128.90** | 57.54% | 0 |
| In-place | 7.2838 | 147.41 | 128.99 | 57.58% | 0 |

按 224 GB/s 搬运等效计分字节量，参考时间为 **4.1943 ms**。占比是 `busBw / 224 × 100%`，用于对照 BW1100 标称带宽。

## 旧版记录

用户提供的 BW1100 旧版 1G 截图中，DTK 26.04-rc4 为 129.37 GB/s，26.04.1-rc1 为 129.46 GB/s。截图未标注数据类型和就地模式。
