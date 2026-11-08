# Reduce · BW1100 带宽公式

n = 8，s = 4 B（FP32），M = 1 GiB = 1,073,741,824 B。卡间标称参考 **224 GB/s**。 [源码](../../../rccl-tests/src/reduce.cu) · [图解](Reduce_busbw.html)

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
    <div class="bw-title">Reduce · BW1100 带宽公式</div>
    <div class="bw-sub">BW1100 (NMZ) ×8，DTK 26.10，FP32，1 GiB，卡间参考 224 GB/s</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="ah" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
              <path d="M1 1 L7 4 L1 7 Z" fill="#7c5cff"/>
            </marker>
          </defs>
          <!-- 树形连线 子→父 向上（规约） -->
          <g stroke="#7c5cff" stroke-width="2" fill="none">
            <line x1="101" y1="116" x2="139" y2="69"  marker-end="url(#ah)"/>
            <line x1="199" y1="116" x2="161" y2="69"  marker-end="url(#ah)"/>
            <line x1="63"  y1="189" x2="82"  y2="146" marker-end="url(#ah)"/>
            <line x1="117" y1="189" x2="98"  y2="146" marker-end="url(#ah)"/>
            <line x1="191" y1="188" x2="204" y2="147" marker-end="url(#ah)"/>
            <line x1="246" y1="190" x2="219" y2="145" marker-end="url(#ah)"/>
            <line x1="144" y1="263" x2="131" y2="222" marker-end="url(#ah)"/>
          </g>
          <!-- M=1 GiB 标注（root 旁） -->
          <g>
            <rect x="176" y="37" width="70" height="18" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="211" y="46" text-anchor="middle" dominant-baseline="central" font-size="11" fill="#1a1a2e">M=1 GiB</text>
          </g>
          <!-- 节点 -->
          <g font-size="12" fill="#1a1a2e" text-anchor="middle" dominant-baseline="central">
            <circle cx="150" cy="55"  r="18" stroke="#7c5cff" fill="#efebff" stroke-width="2"/><text x="150" y="55">G0</text>
            <circle cx="90"  cy="130" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="90"  y="130">G1</text>
            <circle cx="210" cy="130" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="210" y="130">G2</text>
            <circle cx="55"  cy="205" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="55"  y="205">G3</text>
            <circle cx="125" cy="205" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="125" y="205">G4</text>
            <circle cx="185" cy="205" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="185" y="205">G5</text>
            <circle cx="255" cy="205" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="255" y="205">G6</text>
            <circle cx="150" cy="280" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="150" y="280">G7</text>
          </g>
          <!-- 底部标注 -->
          <g>
            <rect x="80" y="312" width="140" height="22" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="150" y="323" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#1a1a2e">流水线树 · T ≈ M/B</text>
          </g>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">root 得到 1 GiB 规约结果</div>
        <div class="bw-step"><span class="n">1</span><span class="t">c = 268,435,456，s = 4 B</span><span class="d">c 取日志中的 count</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">Q = c × s，f = 1</span><span class="d">Q × f = 1,024 MiB</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">t = 8.2015 ms</span><span class="d">DTK 26.10 out-of-place 中位数</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">busBw = Q × f / (t × 10⁶) ≈ 130.92 GB/s</span><span class="d">占 224 GB/s 的 58.45%</span></div>
        <div class="bw-concl">
          <div>In-place <span class="k">130.95 GB/s</span>（#wrong=0）</div>
          <div class="h">按 224 GB/s 折算的参考时间为 4.7935 ms。</div>
        </div>
      </div>
    </div>
  </div>

</div>

## 源码口径

```text
Q = c × s
f = 1
algBw (GB/s) = Q / (t_us × 1000)
busBw (GB/s) = Q × f / (t_us × 1000)
```

`c` 为测试表中 `count` 的元素个数，`s` 为每元素字节数，`t_us` 为测试表中的耗时（µs）。本例 `c` = 268,435,456，计分字节量 `Q × f` = **1,024 MiB**。

每 rank 贡献 1 GiB，root 得到 1 GiB 的规约结果。计分以一份输入的字节量为基数，f 为 1。规约或树形转发引入的额外工作反映在实测耗时中。

## DTK 26.10 复测命令

在 `rccl-tests/build` 下用 Bash 运行。每轮执行三次正确性检查。1 GiB FP32 out-of-place BusBW 三轮中位数为 **131.39 GB/s**。

完整扫包曾在 64 MiB 和 128 MiB 出现校验错误。以下配置的验收范围为 1 GiB out-of-place。

```bash
source /opt/dtk/env.sh
topo_dir=$(mktemp -d)
RCCL_FORCE_DETECT_TOPO=1 RCCL_TOPO_FILE_NAME="$topo_dir/reduce.xml" \
    timeout -k 8s 90s ./reduce_perf -b 1G -e 1G -f 2 -n 20 -w 5 -c 3 -O 1 -t 8 -g 1 -G 4
```

## 1 GiB 实测

DTK 26.10，RCCL 2.27.7（`3b793e3`），单进程 1 线程管 8 卡（`-b 1M -e 1G -f 2 -g 8`），FP32，默认通信参数，3 轮中位数。

| 模式 | 耗时（ms） | algBw（GB/s） | busBw（GB/s） | 占 224 GB/s | #wrong |
| --- | ---: | ---: | ---: | ---: | ---: |
| Out-of-place | 8.2015 | 130.92 | **130.92** | 58.45% | 0 |
| In-place | 8.1996 | 130.95 | 130.95 | 58.46% | 0 |

按 224 GB/s 搬运等效计分字节量，参考时间为 **4.7935 ms**。占比是 `busBw / 224 × 100%`，用于对照 BW1100 标称带宽。

## 旧版记录

用户提供的 BW1100 旧版 1G 截图中，DTK 26.04-rc4 为 131.29 GB/s，26.04.1-rc1 为 131.33 GB/s。截图未标注数据类型和就地模式。
