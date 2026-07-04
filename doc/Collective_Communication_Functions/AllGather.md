# AllGather · busBw 推导与手算

> 源码位置：`rccl-tests/src/all_gather.cu` 第 39-45 行
> 统一场景：n = 8 GPU，rccl-tests 命令行 `-b 134217728`（count = 128 MB）

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
</style>

  <div class="bw-root">
    <div class="bw-title">Ring AllGather · busBw 理论上限推导</div>
    <div class="bw-sub">源码 all_gather.cu: factor = (n−1)/n，n = 8 GPU，M = 128 MB</div>
    <div class="bw-src">baseBw = count*typesize*n / 1e9 / sec;&nbsp;&nbsp;factor = (n−1)/n;&nbsp;&nbsp;busBw = baseBw * factor</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="ah" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="8" markerHeight="8" markerUnits="userSpaceOnUse" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#7c5cff"/>
            </marker>
          </defs>
          <line x1="238.1" y1="186.6" x2="224.1" y2="220.6" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="200.6" y1="244.1" x2="166.6" y2="258.1" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="133.4" y1="258.1" x2="99.4"  y2="244.1" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="75.9"  y1="220.6" x2="61.9"  y2="186.6" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="61.9"  y1="153.4" x2="75.9"  y2="119.4" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="99.4"  y1="95.9"  x2="133.4" y2="81.9"  stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="166.6" y1="81.9"  x2="200.6" y2="95.9"  stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
          <line x1="224.1" y1="119.4" x2="238.1" y2="153.4" stroke="#7c5cff" stroke-width="2.5" marker-end="url(#ah)"/>
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
          <rect x="65" y="298" width="170" height="30" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
          <text x="150" y="313" text-anchor="middle" dominant-baseline="central" font-family="SF Mono, monospace" font-size="10" fill="#1a1a2e">单阶段 AllGather · 7 步 × 16 MB</text>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">busBw 推导链</div>
        <div class="bw-step"><span class="n">1</span><span class="t">M = 128 MB, n = 8</span><span class="d">每 rank 贡献 base = M/n = 16MB，聚合结果 128MB</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">每步传 base = 16 MB，走 n−1 = 7 步</span><span class="d">绕环一周收集所有 rank 数据</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">T = (n−1)·base / B = (n−1)·M / (n·B)</span><span class="d">总传输量除以单向链路带宽</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">algBw = M/T = n·B/(n−1) = 8B/7 ≈ 1.143 B</span><span class="d">有效数据量 / 耗时</span></div>
        <div class="bw-step"><span class="n">5</span><span class="t">busBw = algBw × (n−1)/n = (8B/7)×(7/8) = B ✓</span><span class="d">乘以源码 factor = (n−1)/n</span></div>
        <div class="bw-concl">
          <div>busBw = <span class="k">B</span>（单向链路带宽），与 n、M 无关。</div>
          <div class="h">AllGather 是 AllReduce 第二阶段的半体；algBw &gt; B 因为有用数据是 n 份而链路只转发 n−1 份</div>
        </div>
        <div class="bw-legend">
          <span>每步数据量 <b>base=16MB</b></span>
          <span>步数 <b>n−1=7</b></span>
          <span>每 rank 总传输 <b>7×16=112MB</b></span>
          <span>factor <b>(n−1)/n=0.875</b></span>
        </div>
      </div>
    </div>
  </div>

</div>

## 一、源码公式

```c
void AllGatherGetBw(size_t count, int typesize, double sec,
                    double* algBw, double* busBw, int nranks) {
  double baseBw = (double)(count * typesize * nranks) / 1.0E9 / sec;
  *algBw = baseBw;
  double factor = ((double)(nranks - 1))/((double)nranks);
  *busBw = baseBw * factor;
}
```

- `count` = paramcount = 每 rank **贡献（发送）**字节数 base（注意：不是用户 -b 的原始 count）
- `baseBw` = base × n / T = 总聚合结果 / T
- `factor` = (n−1)/n

> **注意 baseBw 与 AllReduce 不同**：这里多乘了 nranks，因为 AllGather 的"有用输出"是 n 份聚合数据，而每 rank 只贡献其中 1 份。

## 二、参数含义（用户 -b 128MB, n = 8）

AllGatherGetCollByteCount 中：`base = (count/nranks)`，即用户 -b 的 128MB 被 n 等分。

| 量                | 计算          | 值                    |
| ----------------- | ------------- | --------------------- |
| 用户 -b count     | 原始指定      | 128 MB                |
| base = paramcount | count/n       | 16 MB（每 rank 贡献） |
| sendcount / rank  | = base        | 16 MB                 |
| recvcount / rank  | = base×n     | 128 MB（聚合结果）    |
| baseBw 对应数据   | paramcount×n | 128 MB                |

## 三、算法推导（Ring AllGather）

Ring AllGather 单阶段，绕环 n−1 步，每步传 base：

```mermaid
graph LR
    G0["G0<br/>贡献16MB"] -->|base| G1["G1"]
    G1 -->|base| G2["G2"]
    G2 -->|base| G3["..."]
    G3 -->|base| G4["G7"]
    G4 -.->|绕环 n-1=7 步<br/>每步传 16MB| G0
```

- 每步数据量 = base = M/n = 16 MB（M = 128MB 聚合总量）
- 步数 = n−1 = 7（绕环一周即收集到所有 rank 的数据）
- 每步耗时 = base/B
- 总时间：

```
T = (n-1) × base / B = 7 × 16MB / B = 112 MB / B
```

## 四、手算过程

设 B = 单向链路带宽，M = 128MB（聚合总量）。

| 步骤              | 公式                            | 代入 n=8, M=128MB | 结果            |
| ----------------- | ------------------------------- | ----------------- | --------------- |
| 1. 每 rank 贡献   | base = M/n                      | 128/8             | 16 MB           |
| 2. 步数           | n−1                            | 8−1              | 7               |
| 3. 总时间 T       | (n−1)·base/B = (n−1)·M/(nB) | 7×128/(8B)       | 112/B MB        |
| 4. algBw (baseBw) | M/T                             | 128/(112/B)       | 8B/7 ≈ 1.143 B |
| 5. factor         | (n−1)/n                        | 7/8               | 0.875           |
| 6.**busBw** | algBw × factor                 | (8B/7)×(7/8)     | **= B**   |

## 五、理论上限结论

**busBw 理论上限 = B（单向链路带宽），与 n、M 无关。**

- algBw > B（8B/7 ≈ 1.143B）是因为 AllGather 的"有用数据"是 n 份，而每 rank 只需在环上转发 n−1 份，链路复用率高
- factor = (n−1)/n 把这层放大抵消，busBw 回归到单链路带宽 B
- AllGather 是 AllReduce 第二阶段的"半体"，与 ReduceScatter 互为镜像

> **对比 AllReduce**：AllGather 只走一阶段（n−1 步），所以 factor 是 (n−1)/n 而非 2(n−1)/n；algBw 更高（1.143B vs 0.571B），因为有用数据占比更大。
