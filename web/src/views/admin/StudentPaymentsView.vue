<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { brl } from "../../utils/format";
import StudentMonthlyTable from "../../components/StudentMonthlyTable.vue";

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
    error.value = e.response?.status === 403
      ? "Você não tem acesso a este aluno."
      : "Não foi possível carregar os pagamentos.";
  } finally {
    loading.value = false;
  }
}
watch(() => props.id, load, { immediate: true });

const totals = computed(() => summary.value?.totals);
const balance = computed(() => totals.value?.balance_cents ?? 0);
const ahead = computed(() => balance.value >= 0);
</script>

<template>
  <div>
    <RouterLink :to="{ name: 'admin-students' }" class="muted">← Alunos</RouterLink>

    <div v-if="loading" class="muted" style="margin-top:.8rem">Carregando...</div>
    <p v-else-if="error" class="negative">{{ error }}</p>

    <template v-else-if="summary">
      <div class="title-row" style="margin-top:.5rem">
        <h2>{{ summary.student.full_name }}</h2>
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

      <div style="margin-top: 1.5rem">
        <StudentMonthlyTable
          :rows="summary.months || []"
          :currency="totals.currency"
          :bank-updated-through="summary.bank_updated_through"
        />
      </div>
    </template>
  </div>
</template>
