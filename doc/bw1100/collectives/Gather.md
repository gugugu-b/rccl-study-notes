# Gather · BW1100 带宽公式

n = 8，s = 4 B（FP32），M = 1 GiB = 1,073,741,824 B。卡间标称参考 **224 GB/s**。 [源码](../../../rccl-tests/src/gather.cu) · [图解](Gather_busbw.html)

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
  .bw-sub { font-size: 12px; color: var(--text-muted); margin: 0 0 16px; }
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
  .bw-legend { display: flex; gap: 16px; font-size: 12px; color: var(--text-muted); margin-top: 10px; flex-wrap: wrap; }
  .bw-legend span b { color: var(--text); font-weight: var(--weight-medium); }
  @media (max-width: 720px) {
    .bw-grid { flex-direction: column; align-items: center; }
    .bw-ring { flex: auto; max-width: 100%; }
    .bw-ring svg { max-width: 100%; height: auto; }
    .bw-step { flex-wrap: wrap; }
  }
</style>

  <div class="bw-root">
    <div class="bw-title">Gather · BW1100 带宽公式</div>
    <div class="bw-sub">BW1100 (NMZ) ×8，DTK 26.10，FP32，1 GiB，卡间参考 224 GB/s</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="ah" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#7c5cff"/>
            </marker>
          </defs>
          <!-- 根扇入连线 Gi→G0 -->
          <g stroke="#7c5cff" stroke-width="2" fill="none">
            <line x1="219" y1="84"  x2="76"  y2="161" marker-end="url(#ah)"/>
            <line x1="251" y1="122" x2="77"  y2="166" marker-end="url(#ah)"/>
            <line x1="260" y1="170" x2="78"  y2="170" marker-end="url(#ah)"/>
            <line x1="251" y1="218" x2="77"  y2="174" marker-end="url(#ah)"/>
            <line x1="219" y1="256" x2="76"  y2="179" marker-end="url(#ah)"/>
            <line x1="175" y1="280" x2="73"  y2="182" marker-end="url(#ah)"/>
            <line x1="129" y1="283" x2="69"  y2="185" marker-end="url(#ah)"/>
          </g>
          <!-- 每条箭头标注 base=128 MiB（白色描边保证可读） -->
          <g font-size="9" fill="#6b6b80" stroke="#ffffff" stroke-width="3" paint-order="stroke" text-anchor="middle" dominant-baseline="central">
            <text x="183" y="104">128 MiB</text>
            <text x="206" y="134">128 MiB</text>
            <text x="213" y="170">128 MiB</text>
            <text x="206" y="206">128 MiB</text>
            <text x="183" y="237">128 MiB</text>
            <text x="150" y="255">128 MiB</text>
            <text x="115" y="260">128 MiB</text>
          </g>
          <!-- root 标注 收 8×128 MiB=1 GiB（G0 上方两行） -->
          <g font-size="10" fill="#5b3fd6" text-anchor="middle" dominant-baseline="central">
            <text x="60" y="128">收 8×128 MiB</text>
            <text x="60" y="142">= 1 GiB</text>
          </g>
          <!-- 节点 -->
          <g font-size="12" fill="#1a1a2e" text-anchor="middle" dominant-baseline="central">
            <circle cx="60"  cy="170" r="18" stroke="#7c5cff" fill="#efebff" stroke-width="2"/><text x="60"  y="170">G0</text>
            <circle cx="235" cy="75"  r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="235" y="75">G1</text>
            <circle cx="268" cy="118" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="268" y="118">G2</text>
            <circle cx="278" cy="170" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="278" y="170">G3</text>
            <circle cx="268" cy="222" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="268" y="222">G4</text>
            <circle cx="235" cy="265" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="235" y="265">G5</text>
            <circle cx="188" cy="292" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="188" y="292">G6</text>
            <circle cx="138" cy="298" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="138" y="298">G7</text>
          </g>
          <!-- 底部标注 -->
          <g>
            <rect x="80" y="321" width="140" height="16" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="150" y="329" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e">根扇入 · 7 × 128 MiB</text>
          </g>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">root 接收 7 份远端分片</div>
        <div class="bw-step"><span class="n">1</span><span class="t">c = 33,554,432，s = 4 B</span><span class="d">c 取日志中的 count</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">Q = n × c × s，f = (n−1)/n</span><span class="d">Q × f = 896 MiB</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">t = 5.7922 ms</span><span class="d">DTK 26.10 out-of-place 中位数</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">busBw = Q × f / (t × 10⁶) ≈ 162.21 GB/s</span><span class="d">占 224 GB/s 的 72.42%</span></div>
        <div class="bw-concl">
          <div>In-place <span class="k">162.15 GB/s</span>（#wrong=0）</div>
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

每 rank 提供 128 MiB，root 得到 1 GiB，其中 896 MiB 来自其他 rank。源端和 root 的并发程度会影响耗时，f 只按消息大小折算。

## DTK 26.10 复测命令

在 `rccl-tests/build` 下用 Bash 运行。覆盖 1 MiB 至 1 GiB 的完整扫包。1 GiB FP32 out-of-place BusBW 三轮中位数为 **164.27 GB/s**。

```bash
source /opt/dtk/env.sh
topo_dir=$(mktemp -d)
RCCL_FORCE_DETECT_TOPO=1 RCCL_TOPO_FILE_NAME="$topo_dir/gather.xml" \
    timeout -k 8s 90s ./gather_perf -b 1M -e 1G -f 2 -t 8 -g 1
```

## 1 GiB 实测

DTK 26.10，RCCL 2.27.7（`3b793e3`），单进程 1 线程管 8 卡（`-b 1M -e 1G -f 2 -g 8`），FP32，默认通信参数，3 轮中位数。

| 模式 | 耗时（ms） | algBw（GB/s） | busBw（GB/s） | 占 224 GB/s | #wrong |
| --- | ---: | ---: | ---: | ---: | ---: |
| Out-of-place | 5.7922 | 185.38 | **162.21** | 72.42% | 0 |
| In-place | 5.7942 | 185.31 | 162.15 | 72.39% | 0 |

按 224 GB/s 搬运等效计分字节量，参考时间为 **4.1943 ms**。占比是 `busBw / 224 × 100%`，用于对照 BW1100 标称带宽。

## 旧版记录

用户提供的 BW1100 旧版 1G 截图中，DTK 26.04-rc4 为 163.94 GB/s，26.04.1-rc1 为 163.94 GB/s。截图未标注数据类型和就地模式。
