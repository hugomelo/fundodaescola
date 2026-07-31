<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl, percent } from "../../utils/format";

const admin = useAdminStore();
const data = ref(null);
const sortKey = ref("balance_cents");

async function load() {
  const { data: res } = await client.get(`/admin/grades/${admin.currentGradeId}/dashboard`);
  data.value = res;
}
watch(() => admin.currentGradeId, load, { immediate: true });

const students = computed(() => {
  if (!data.value) return [];
  return [...data.value.students].sort((a, b) => {
    if (sortKey.value === "full_name") return a.full_name.localeCompare(b.full_name);
    return a[sortKey.value] - b[sortKey.value];
  });
});
const g = computed(() => data.value?.grade);
</script>

<template>
  <div v-if="data">
    <div class="card">
      <div class="title-row">
        <h2>{{ g.name }}</h2>
        <span class="badge green">{{ percent(g.progress_ratio) }} da meta</span>
      </div>
      <div class="progress"><span :style="{ width: Math.min(100, g.progress_ratio * 100) + '%' }"></span></div>
      <div class="grid cols-3" style="margin-top: 1.2rem">
        <div class="stat"><span class="value">{{ brl(g.net_raised_cents) }}</span><span class="label">Arrecadado</span></div>
        <div class="stat"><span class="value">{{ brl(g.target_total_cents) }}</span><span class="label">Meta</span></div>
        <div class="stat"><span class="value">{{ g.students_count }}</span><span class="label">Alunos</span></div>
      </div>
      <div class="row breakdown">
        <span>Contribuições: <strong>{{ brl(g.student_contributions_cents) }}</strong></span>
        <span>Eventos: <strong>{{ brl(g.event_cents) }}</strong></span>
        <span>Rendimentos: <strong>{{ brl(g.investment_cents) }}</strong></span>
      </div>
    </div>

    <div class="card" style="margin-top: 1.5rem">
      <div class="title-row">
        <h2>Saldo por aluno</h2>
        <select v-model="sortKey">
          <option value="balance_cents">Ordenar por saldo</option>
          <option value="full_name">Ordenar por nome</option>
          <option value="contributed_cents">Ordenar por contribuído</option>
        </select>
      </div>
      <table>
        <thead>
          <tr><th>Aluno</th><th class="right">Contribuído</th><th class="right">Esperado</th><th class="right">Saldo</th></tr>
        </thead>
        <tbody>
          <tr v-for="s in students" :key="s.id">
            <td>
              <RouterLink :to="{ name: 'admin-student', params: { id: s.id } }">{{ s.full_name }}</RouterLink>
              <span v-if="!s.active" class="badge red" style="margin-left:.4rem">inativo</span>
            </td>
            <td class="right">{{ brl(s.contributed_cents) }}</td>
            <td class="right">{{ brl(s.expected_cents) }}</td>
            <td class="right" :class="s.balance_cents >= 0 ? 'positive' : 'negative'">
              {{ s.balance_cents >= 0 ? "+" : "" }}{{ brl(s.balance_cents) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <p v-else class="muted">Carregando...</p>
</template>

<style scoped>
.breakdown { margin-top: 1rem; padding-top: 1rem; border-top: 1px solid var(--line); color: var(--muted); font-size: 0.9rem; }
.breakdown span { margin-right: 0.5rem; }
</style>
