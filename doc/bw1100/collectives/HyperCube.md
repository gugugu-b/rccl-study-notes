# HyperCube · BW1100 带宽公式

n = 8，s = 4 B（FP32），M = 1 GiB = 1,073,741,824 B。卡间标称参考 **224 GB/s**。 [源码](../../../rccl-tests/src/hypercube.cu) · [图解](HyperCube_busbw.html)

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
    <div class="bw-title">HyperCube · BW1100 带宽公式</div>
    <div class="bw-sub">BW1100 (NMZ) ×8，DTK 26.10，FP32，1 GiB，卡间参考 224 GB/s</div>
    <div class="bw-grid">
      <div class="bw-ring">
        <svg viewBox="0 0 300 340" width="300" height="340" xmlns="http://www.w3.org/2000/svg">
          <!-- 轮0 维0 前后层连线（虚线·浅） -->
          <g stroke="#7c5cff" stroke-width="2.5" stroke-opacity="0.4" stroke-dasharray="5 4">
            <line x1="80"  y1="120" x2="120" y2="80"/>
            <line x1="180" y1="100" x2="220" y2="60"/>
            <line x1="200" y1="200" x2="240" y2="160"/>
            <line x1="85"  y1="220" x2="140" y2="180"/>
          </g>
          <!-- 轮1 维1 水平边（实线·中） -->
          <g stroke="#7c5cff" stroke-width="2.5" stroke-opacity="0.65">
            <line x1="80"  y1="120" x2="180" y2="100"/>
            <line x1="200" y1="200" x2="85"  y2="220"/>
            <line x1="120" y1="80"  x2="220" y2="60"/>
            <line x1="240" y1="160" x2="140" y2="180"/>
          </g>
          <!-- 轮2 维2 垂直边（实线·满） -->
          <g stroke="#7c5cff" stroke-width="2.5" stroke-opacity="1">
            <line x1="80"  y1="120" x2="85"  y2="220"/>
            <line x1="180" y1="100" x2="200" y2="200"/>
            <line x1="120" y1="80"  x2="140" y2="180"/>
            <line x1="220" y1="60"  x2="240" y2="160"/>
          </g>
          <!-- 节点 -->
          <g font-size="12" fill="#1a1a2e" text-anchor="middle" dominant-baseline="central">
            <circle cx="80"  cy="120" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="80"  y="120">G0</text>
            <circle cx="180" cy="100" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="180" y="100">G1</text>
            <circle cx="200" cy="200" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="200" y="200">G2</text>
            <circle cx="85"  cy="220" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="85"  y="220">G3</text>
            <circle cx="120" cy="80"  r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="120" y="80">G4</text>
            <circle cx="220" cy="60"  r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="220" y="60">G5</text>
            <circle cx="240" cy="160" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="240" y="160">G6</text>
            <circle cx="140" cy="180" r="18" stroke="#7c5cff" fill="#ffffff" stroke-width="2"/><text x="140" y="180">G7</text>
          </g>
          <!-- 轮0 标注（G0-G4 旁） -->
          <g>
            <rect x="8" y="74" width="84" height="16" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="50" y="82" text-anchor="middle" dominant-baseline="central" font-size="10" fill="#1a1a2e">轮0 128 MiB</text>
          </g>
          <!-- 轮1 标注（G2-G3 旁） -->
          <g>
            <rect x="105" y="242" width="100" height="16" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="155" y="250" text-anchor="middle" dominant-baseline="central" font-size="10" fill="#1a1a2e">轮1 256 MiB</text>
          </g>
          <!-- 轮2 标注（G5-G6 旁） -->
          <g>
            <rect x="200" y="102" width="98" height="16" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="249" y="110" text-anchor="middle" dominant-baseline="central" font-size="10" fill="#1a1a2e">轮2 512 MiB</text>
          </g>
          <!-- 底部标注 -->
          <g>
            <rect x="60" y="298" width="180" height="24" rx="6" fill="#efebff" stroke="#7c5cff" stroke-width="1"/>
            <text x="150" y="310" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#1a1a2e">超立方体 · 3 轮 × 串行</text>
          </g>
        </svg>
      </div>
      <div class="bw-derive">
        <div class="bw-derive-head">交换 128、256、512 MiB</div>
        <div class="bw-step"><span class="n">1</span><span class="t">c = 33,554,432，s = 4 B</span><span class="d">c 取日志中的 count</span></div>
        <div class="bw-step"><span class="n">2</span><span class="t">Q = (n−1) × c × s，f = 1</span><span class="d">Q × f = 896 MiB</span></div>
        <div class="bw-step"><span class="n">3</span><span class="t">t = 8.2375 ms</span><span class="d">DTK 26.10 out-of-place 中位数</span></div>
        <div class="bw-step"><span class="n">4</span><span class="t">busBw = Q × f / (t × 10⁶) ≈ 114.06 GB/s</span><span class="d">占 224 GB/s 的 50.92%</span></div>
        <div class="bw-concl">
          <div>In-place <span class="k">116.22 GB/s</span>（#wrong=0）</div>
          <div class="h">按 224 GB/s 折算的参考时间为 4.1943 ms。</div>
        </div>
      </div>
    </div>
  </div>

</div>

## 源码口径

```text
Q = (n−1) × c × s
f = 1
algBw (GB/s) = Q / (t_us × 1000)
busBw (GB/s) = Q × f / (t_us × 1000)
```

`c` 为测试表中 `count` 的元素个数，`s` 为每元素字节数，`t_us` 为测试表中的耗时（µs）。本例 `c` = 33,554,432，计分字节量 `Q × f` = **896 MiB**。

这是 rccl-tests 实现的递归倍增 AllGather。8 个 rank 通过掩码 1、2、4 分别交换 128、256、512 MiB，合计 896 MiB。algBw 从一开始就按远端数据计量，因此 f 为 1。rank 数需为 2 的幂，单机 8 rank 满足条件。

## DTK 26.10 复测命令

在 `rccl-tests/build` 下用 Bash 运行。覆盖 1 MiB 至 1 GiB 的完整扫包。1 GiB FP32 out-of-place BusBW 三轮中位数为 **113.94 GB/s**。

该配置使用 8 线程、每线程 1 卡。旧版截图缺少该算子，调优筛选未测得稳定提升。

```bash
source /opt/dtk/env.sh
topo_dir=$(mktemp -d)
RCCL_FORCE_DETECT_TOPO=1 RCCL_TOPO_FILE_NAME="$topo_dir/hypercube.xml" \
    timeout -k 8s 90s ./hypercube_perf -b 1M -e 1G -f 2 -t 8 -g 1
```

## 1 GiB 实测

DTK 26.10，RCCL 2.27.7（`3b793e3`），单进程 8 线程、每线程 1 卡（`-b 1M -e 1G -f 2 -t 8 -g 1`），FP32，默认通信参数，3 轮中位数。

| 模式 | 耗时（ms） | algBw（GB/s） | busBw（GB/s） | 占 224 GB/s | #wrong |
| --- | ---: | ---: | ---: | ---: | ---: |
| Out-of-place | 8.2375 | 114.06 | **114.06** | 50.92% | 0 |
| In-place | 8.0840 | 116.22 | 116.22 | 51.88% | 0 |

按 224 GB/s 搬运等效计分字节量，参考时间为 **4.1943 ms**。占比是 `busBw / 224 × 100%`，用于对照 BW1100 标称带宽。

单线程管 8 卡的 `-g 8` 用例三轮均校验失败。上表取 8 线程每线程 1 卡的三轮通过结果。

## 旧版记录

旧版截图未列出 HyperCube。
