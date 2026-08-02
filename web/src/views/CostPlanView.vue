<script setup>
import { ref, watch, computed } from "vue";
import client from "../api/client";
import { brl, percent } from "../utils/format";

const props = defineProps({ gradeId: { type: [Number, String], required: true } });
const plan = ref(null);
const error = ref("");

async function load() {
  error.value = "";
  try {
    const { data } = await client.get(`/grades/${props.gradeId}/cost_plan`);
    plan.value = data;
  } catch (e) {
    error.value = e.response?.status === 403 ? "Você não tem acesso a esta turma." : "Não foi possível carregar o plano.";
  }
}
watch(() => props.gradeId, load, { immediate: true });

const raisedRatio = computed(() => {
  if (!plan.value || !plan.value.total_needed_cents) return 0;
  return plan.value.net_raised_cents / plan.value.total_needed_cents;
});
const remaining = computed(() =>
  Math.max((plan.value?.total_needed_cents || 0) - (plan.value?.net_raised_cents || 0), 0)
);
</script>

<template>
  <div class="container">
    <RouterLink to="/" class="muted">← Voltar</RouterLink>
    <p v-if="error" class="negative">{{ error }}</p>

    <template v-if="plan">
      <h1>Quanto a turma precisa acumular</h1>
      <p class="muted">
        As viagens de cada ano têm custo estimado a partir de valores reais informados por
        outras turmas, corrigidos pela inflação de {{ percent(plan.inflation_rate) }} ao ano até a
        data da viagem. Quando um custo real do ano é informado, ele substitui a estimativa.
      </p>

      <div class="grid cols-3">
        <div class="card stat">
          <span class="value">{{ brl(plan.total_needed_cents, plan.currency) }}</span>
          <span class="label">Total a acumular (toda a jornada)</span>
        </div>
        <div class="card stat">
          <span class="value">{{ brl(plan.total_per_student_cents, plan.currency) }}</span>
          <span class="label">Por aluno ({{ plan.active_students }} ativos)</span>
        </div>
        <div class="card stat">
          <span class="value negative">{{ brl(remaining, plan.currency) }}</span>
          <span class="label">Falta arrecadar</span>
        </div>
      </div>

      <div class="card" style="margin-top:1.5rem">
        <div class="title-row">
          <h2>Progresso</h2>
          <span class="badge green">{{ percent(raisedRatio) }}</span>
        </div>
        <div class="progress"><span :style="{ width: Math.min(100, raisedRatio * 100) + '%' }"></span></div>
        <p class="muted" style="margin-top:.6rem">
          Já arrecadado: <strong>{{ brl(plan.net_raised_cents, plan.currency) }}</strong>
          de <strong>{{ brl(plan.total_needed_cents, plan.currency) }}</strong>.
        </p>
      </div>

      <div class="card" style="margin-top:1.5rem">
        <h2>Viagens e custo estimado</h2>
        <table>
          <thead>
            <tr><th>Ano</th><th>Viagem</th><th class="center">Ano da viagem</th><th class="right">Custo por aluno</th></tr>
          </thead>
          <tbody>
            <tr v-for="t in plan.trips" :key="t.id">
              <td>{{ t.level }}</td>
              <td>{{ t.name }}</td>
              <td class="center">{{ t.trip_year }}</td>
              <td class="right">
                {{ brl(t.cost_cents, plan.currency) }}
                <span class="badge" :class="t.is_actual ? 'green' : ''">{{ t.is_actual ? "real" : "estimado" }}</span>
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr>
              <td colspan="3" class="right"><strong>Total por aluno</strong></td>
              <td class="right"><strong>{{ brl(plan.total_per_student_cents, plan.currency) }}</strong></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </template>
  </div>
</template>

<style scoped>
tfoot td { border-top: 2px solid var(--line); }
.badge { margin-left: 0.4rem; }
</style>
