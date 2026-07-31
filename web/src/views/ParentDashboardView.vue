<script setup>
import { ref, watch, computed } from "vue";
import client from "../api/client";
import { brl, monthLabel } from "../utils/format";
import GradeOverview from "../components/GradeOverview.vue";

const props = defineProps({ id: { type: [Number, String], required: true } });

const summary = ref(null);
const error = ref("");
const loading = ref(true);

async function load() {
  loading.value = true;
  error.value = "";
  try {
    const { data } = await client.get(`/students/${props.id}/summary`);
    summary.value = data;
  } catch (e) {
    error.value = e.response?.status === 403 ? "Você não tem acesso a este aluno." : "Não foi possível carregar os dados.";
  } finally {
    loading.value = false;
  }
}
watch(() => props.id, load, { immediate: true });

const totals = computed(() => summary.value?.totals);
const balance = computed(() => totals.value?.balance_cents ?? 0);
const ahead = computed(() => balance.value >= 0);

// per-month running balance for context
const rows = computed(() => summary.value?.months || []);
</script>

<template>
  <div class="container">
    <RouterLink to="/" class="muted back">← Voltar</RouterLink>

    <div v-if="loading" class="muted">Carregando...</div>
    <p v-else-if="error" class="negative">{{ error }}</p>

    <template v-else-if="summary">
      <div class="title-row">
        <h1>{{ summary.student.display_name }}</h1>
        <span class="badge" :class="ahead ? 'green' : 'red'">
          {{ ahead ? "Em dia / adiantado" : "Em atraso" }}
        </span>
      </div>

      <div class="grid cols-3">
        <div class="card stat">
          <span class="value">{{ brl(totals.contributed_cents, totals.currency) }}</span>
          <span class="label">Total contribuído</span>
        </div>
        <div class="card stat">
          <span class="value">{{ brl(totals.expected_cents, totals.currency) }}</span>
          <span class="label">Esperado até o mês atual</span>
        </div>
        <div class="card stat">
          <span class="value" :class="ahead ? 'positive' : 'negative'">
            {{ ahead ? "+" : "" }}{{ brl(balance, totals.currency) }}
          </span>
          <span class="label">{{ ahead ? "Adiantado / saldo" : "Faltando" }}</span>
        </div>
      </div>

      <div class="card" style="margin-top: 1.5rem">
        <h2>Mês a mês</h2>
        <table>
          <thead>
            <tr><th>Mês</th><th class="right">Prometido</th><th class="right">Contribuído</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="r in rows" :key="r.month">
              <td>{{ monthLabel(r.month) }}</td>
              <td class="right">{{ r.pledged_cents != null ? brl(r.pledged_cents, totals.currency) : "—" }}</td>
              <td class="right">{{ brl(r.contributed_cents, totals.currency) }}</td>
              <td>
                <span
                  v-if="r.pledged_cents != null"
                  class="badge"
                  :class="r.contributed_cents >= r.pledged_cents ? 'green' : 'red'"
                >
                  {{ r.contributed_cents >= r.pledged_cents ? "ok" : "abaixo" }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <p class="muted note">
          O valor contribuído é apurado a partir dos pagamentos identificados na conta.
          Pagamentos adiantados aparecem no mês em que caíram na conta, mas o saldo considera o total acumulado.
        </p>
      </div>

      <div style="margin-top: 1.5rem">
        <GradeOverview :grade-id="summary.student.grade_id" />
      </div>
    </template>
  </div>
</template>

<style scoped>
.back { display: inline-block; margin-bottom: 0.8rem; }
.note { margin-top: 1rem; font-size: 0.85rem; }
</style>
