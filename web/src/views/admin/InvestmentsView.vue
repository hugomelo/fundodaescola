<script setup>
import { ref, watch } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl, monthLabel } from "../../utils/format";

const admin = useAdminStore();
const entries = ref([]);
const totalCents = ref(0);
const form = ref({ month: "", amount: "", note: "" });

async function load() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/investment_entries`);
  entries.value = data.investment_entries;
  totalCents.value = data.total_cents;
}
watch(() => admin.currentGradeId, load, { immediate: true });

async function save() {
  const cents = Math.round(parseFloat(String(form.value.amount).replace(",", ".")) * 100);
  await client.post(`/admin/grades/${admin.currentGradeId}/investment_entries`, {
    investment_entry: { month: form.value.month + "-01", amount_cents: cents, note: form.value.note },
  });
  form.value = { month: "", amount: "", note: "" };
  await load();
}

async function updateAmount(e, amount) {
  const cents = Math.round(parseFloat(String(amount).replace(",", ".")) * 100);
  await client.patch(`/admin/investment_entries/${e.id}`, { investment_entry: { amount_cents: cents } });
  await load();
}

async function remove(e) {
  if (!confirm("Remover este rendimento?")) return;
  await client.delete(`/admin/investment_entries/${e.id}`);
  await load();
}
</script>

<template>
  <div class="card">
    <div class="title-row">
      <h2>Rendimentos mensais</h2>
      <span class="badge green">Total: {{ brl(totalCents) }}</span>
    </div>
    <p class="muted">Informe manualmente o rendimento da aplicação na conta a cada mês. Ele entra no total arrecadado da turma.</p>

    <form class="new-form" @submit.prevent="save">
      <input v-model="form.month" type="month" required />
      <input v-model="form.amount" placeholder="Valor (ex: 150,00)" required />
      <input v-model="form.note" placeholder="Observação (opcional)" />
      <button type="submit">Adicionar / atualizar</button>
    </form>

    <table>
      <thead><tr><th>Mês</th><th class="right">Valor</th><th>Observação</th><th></th></tr></thead>
      <tbody>
        <tr v-for="e in entries" :key="e.id">
          <td>{{ monthLabel(e.month) }}</td>
          <td class="right">
            <input style="width:120px; text-align:right" :value="(e.amount_cents / 100).toFixed(2)" @change="updateAmount(e, $event.target.value)" />
          </td>
          <td class="muted">{{ e.note }}</td>
          <td class="right"><button class="ghost" @click="remove(e)">✕</button></td>
        </tr>
      </tbody>
    </table>
    <p v-if="!entries.length" class="muted center" style="padding:1rem">Nenhum rendimento cadastrado.</p>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin: 1rem 0; padding: 1rem; background: #faf7f0; border-radius: 8px; }
</style>
