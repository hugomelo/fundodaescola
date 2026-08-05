<script setup>
import { ref, watch } from "vue";
import client from "../api/client";
import { brl, percent } from "../utils/format";

const props = defineProps({ gradeId: { type: [Number, String], required: true } });
const data = ref(null);
const error = ref("");

async function load() {
  error.value = "";
  try {
    const res = await client.get(`/grades/${props.gradeId}/overview`);
    data.value = res.data;
  } catch {
    error.value = "Não foi possível carregar o panorama da turma.";
  }
}
watch(() => props.gradeId, load, { immediate: true });
</script>

<template>
  <div class="card" v-if="data">
    <div class="title-row">
      <h2>Panorama da turma</h2>
      <div class="row" style="gap:.4rem">
        <span
          v-if="data.pace_ratio != null"
          class="badge"
          :class="data.pace_ratio >= 1 ? 'green' : 'red'"
        >
          {{ percent(data.pace_ratio) }} do ritmo
        </span>
        <span class="badge green">{{ percent(data.progress_ratio) }} da meta</span>
      </div>
    </div>
    <div class="progress pace-bar">
      <span class="raised" :style="{ width: Math.min(100, data.progress_ratio * 100) + '%' }"></span>
      <i
        v-if="data.target_to_date_cents != null && data.target_total_cents"
        class="pace-mark"
        :style="{ left: Math.min(100, (data.target_to_date_cents / data.target_total_cents) * 100) + '%' }"
        title="Meta até este mês"
      ></i>
    </div>
    <div class="grid cols-3" style="margin-top: 1.2rem">
      <div class="stat">
        <span class="value">{{ brl(data.net_raised_cents) }}</span>
        <span class="label">Arrecadado até agora</span>
      </div>
      <div class="stat">
        <span class="value">{{ data.target_to_date_cents != null ? brl(data.target_to_date_cents) : "—" }}</span>
        <span class="label">Meta até este mês</span>
      </div>
      <div class="stat">
        <span class="value">{{ brl(data.target_total_cents) }}</span>
        <span class="label">Meta (custo total)</span>
      </div>
    </div>
    <p v-if="data.pace_gap_cents > 0" class="pace-gap negative">
      Faltam {{ brl(data.pace_gap_cents) }} para o ritmo necessário até este mês.
    </p>
    <div class="row breakdown">
      <span>Contribuições: <strong>{{ brl(data.student_contributions_cents) }}</strong></span>
      <span>Eventos: <strong>{{ brl(data.event_cents) }}</strong></span>
      <span>Rendimentos: <strong>{{ brl(data.investment_cents) }}</strong></span>
    </div>
  </div>
  <p v-else-if="error" class="negative">{{ error }}</p>
</template>

<style scoped>
.breakdown { margin-top: 1rem; padding-top: 1rem; border-top: 1px solid var(--line); color: var(--muted); font-size: 0.9rem; }
.breakdown span { margin-right: 0.5rem; }
.pace-gap { margin: 1rem 0 0; font-size: 0.95rem; }
.pace-bar { position: relative; overflow: visible; }
.pace-bar .raised {
  display: block;
  height: 100%;
  background: linear-gradient(90deg, var(--primary), var(--amber));
  border-radius: 999px;
  transition: width 0.4s;
}
.pace-mark {
  position: absolute;
  top: -3px;
  bottom: -3px;
  width: 2px;
  margin-left: -1px;
  background: var(--ink);
  border-radius: 1px;
  opacity: 0.55;
}
</style>
