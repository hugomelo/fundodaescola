<script setup>
import { computed, ref } from "vue";
import { brl, monthLabel } from "../utils/format";

const props = defineProps({
  series: { type: Array, default: () => [] },
  /** Field on each series row to plot (e.g. amount_cents, families). */
  valueKey: { type: String, default: "amount_cents" },
  /** "money" formats as BRL; "count" as integers. */
  valueKind: { type: String, default: "money" },
  emptyText: { type: String, default: "Ainda não há dados mensais para exibir." },
  ariaLabel: { type: String, default: "Gráfico mensal" },
});

const hover = ref(null);

const WIDTH = 720;
const HEIGHT = 260;
const PAD = { top: 20, right: 16, bottom: 44, left: 56 };
const plotW = WIDTH - PAD.left - PAD.right;
const plotH = HEIGHT - PAD.top - PAD.bottom;

const points = computed(() =>
  (props.series || []).map((row) => ({
    month: row.month,
    label: monthLabel(row.month),
    value: Number(row[props.valueKey]) || 0,
  }))
);

const maxAbs = computed(() => {
  const vals = points.value.map((p) => Math.abs(p.value));
  const m = Math.max(...vals, 0);
  if (m > 0) return m;
  return props.valueKind === "money" ? 10000 : 4;
});

const yTicks = computed(() => {
  const max = maxAbs.value;
  const step = props.valueKind === "count"
    ? Math.max(1, Math.round(niceStep(max / 4)))
    : niceStep(max / 4);
  const ticks = [];
  for (let v = 0; v <= max + step / 2; v += step) {
    ticks.push(props.valueKind === "count" ? Math.round(v) : v);
  }
  // de-dupe after rounding
  const unique = [...new Set(ticks)];
  if (points.value.some((p) => p.value < 0)) {
    for (let v = -step; v >= -max - step / 2; v -= step) {
      unique.unshift(props.valueKind === "count" ? Math.round(v) : v);
    }
  }
  return unique;
});

const yMin = computed(() => Math.min(0, ...yTicks.value));
const yMax = computed(() => Math.max(0, ...yTicks.value));

function yScale(value) {
  const span = yMax.value - yMin.value || 1;
  return PAD.top + plotH * (1 - (value - yMin.value) / span);
}

function zeroY() {
  return yScale(0);
}

function barX(i) {
  const n = points.value.length || 1;
  const gap = Math.min(8, plotW / n / 4);
  const w = (plotW - gap * (n - 1)) / n;
  return { x: PAD.left + i * (w + gap), w };
}

function niceStep(raw) {
  if (!raw || raw <= 0) return props.valueKind === "money" ? 10000 : 1;
  const exp = Math.pow(10, Math.floor(Math.log10(raw)));
  const f = raw / exp;
  const nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
  return nice * exp;
}

function formatValue(value) {
  if (props.valueKind === "count") {
    return new Intl.NumberFormat("pt-BR").format(value);
  }
  const v = (value || 0) / 100;
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    notation: Math.abs(v) >= 1000 ? "compact" : "standard",
    maximumFractionDigits: Math.abs(v) >= 1000 ? 1 : 0,
  }).format(v);
}

function formatTooltip(value) {
  if (props.valueKind === "count") {
    const n = value;
    return `${new Intl.NumberFormat("pt-BR").format(n)} família${n === 1 ? "" : "s"}`;
  }
  return brl(value);
}

function onEnter(i, e) {
  hover.value = { i, ...points.value[i], clientX: e.clientX, clientY: e.clientY };
}
function onMove(e) {
  if (!hover.value) return;
  hover.value = { ...hover.value, clientX: e.clientX, clientY: e.clientY };
}
function onLeave() {
  hover.value = null;
}

const labelStep = computed(() => {
  const n = points.value.length;
  if (n <= 12) return 1;
  if (n <= 24) return 2;
  return Math.ceil(n / 12);
});
</script>

<template>
  <div class="chart-wrap">
    <p v-if="!points.length" class="muted center empty">{{ emptyText }}</p>
    <svg
      v-else
      class="chart"
      :viewBox="`0 0 ${WIDTH} ${HEIGHT}`"
      role="img"
      :aria-label="ariaLabel"
      @mousemove="onMove"
      @mouseleave="onLeave"
    >
      <g v-for="tick in yTicks" :key="'y' + tick">
        <line
          :x1="PAD.left"
          :x2="PAD.left + plotW"
          :y1="yScale(tick)"
          :y2="yScale(tick)"
          class="grid"
          :class="{ zero: tick === 0 }"
        />
        <text :x="PAD.left - 8" :y="yScale(tick) + 4" class="axis-label" text-anchor="end">
          {{ formatValue(tick) }}
        </text>
      </g>

      <g v-for="(p, i) in points" :key="p.month">
        <rect
          :x="barX(i).x"
          :y="p.value >= 0 ? yScale(p.value) : zeroY()"
          :width="barX(i).w"
          :height="Math.max(1, Math.abs(yScale(p.value) - zeroY()))"
          class="bar"
          :class="{ neg: p.value < 0, active: hover?.i === i }"
          @mouseenter="onEnter(i, $event)"
        />
        <text
          v-if="i % labelStep === 0 || i === points.length - 1"
          :x="barX(i).x + barX(i).w / 2"
          :y="HEIGHT - 14"
          class="axis-label"
          text-anchor="middle"
        >
          {{ p.label }}
        </text>
      </g>
    </svg>

    <div
      v-if="hover"
      class="tooltip"
      :style="{ left: hover.clientX + 'px', top: hover.clientY + 'px' }"
    >
      <strong>{{ hover.label }}</strong>
      <span>{{ formatTooltip(hover.value) }}</span>
    </div>
  </div>
</template>

<style scoped>
.chart-wrap { position: relative; width: 100%; }
.chart { width: 100%; height: auto; display: block; overflow: visible; }
.grid { stroke: var(--line); stroke-width: 1; }
.grid.zero { stroke: var(--muted); stroke-width: 1.25; }
.axis-label { fill: var(--muted); font-size: 11px; }
.bar {
  fill: var(--primary);
  opacity: 0.85;
  transition: opacity 0.15s, fill 0.15s;
  cursor: default;
}
.bar.neg { fill: var(--negative); }
.bar.active, .bar:hover { opacity: 1; fill: var(--amber); }
.bar.neg.active, .bar.neg:hover { fill: var(--negative); opacity: 1; }
.empty { padding: 2rem 0; }
.tooltip {
  position: fixed;
  transform: translate(-50%, calc(-100% - 12px));
  background: var(--ink);
  color: #fff;
  padding: 0.4rem 0.65rem;
  border-radius: 8px;
  font-size: 0.8rem;
  pointer-events: none;
  z-index: 20;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  white-space: nowrap;
  box-shadow: var(--shadow);
}
</style>
