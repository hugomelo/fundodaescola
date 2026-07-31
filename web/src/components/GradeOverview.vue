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
      <span class="badge green">{{ percent(data.progress_ratio) }} da meta</span>
    </div>
    <div class="progress"><span :style="{ width: Math.min(100, data.progress_ratio * 100) + '%' }"></span></div>
    <div class="grid cols-3" style="margin-top: 1.2rem">
      <div class="stat">
        <span class="value">{{ brl(data.net_raised_cents) }}</span>
        <span class="label">Arrecadado até agora</span>
      </div>
      <div class="stat">
        <span class="value">{{ brl(data.target_total_cents) }}</span>
        <span class="label">Meta (custo total)</span>
      </div>
      <div class="stat">
        <span class="value negative">{{ brl(data.remaining_cents) }}</span>
        <span class="label">Falta arrecadar</span>
      </div>
    </div>
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
</style>
