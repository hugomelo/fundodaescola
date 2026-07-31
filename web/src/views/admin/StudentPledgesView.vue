<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { brl, monthLabel } from "../../utils/format";

const props = defineProps({ id: { type: [Number, String], required: true } });
const student = ref(null);
const newPledge = ref({ month: "", amount: "" });

async function load() {
  const { data } = await client.get(`/admin/students/${props.id}`);
  student.value = data.student;
}
watch(() => props.id, load, { immediate: true });

async function addPledge() {
  const cents = Math.round(parseFloat(String(newPledge.value.amount).replace(",", ".")) * 100);
  await client.post(`/admin/students/${props.id}/monthly_pledges`, {
    monthly_pledge: { month: newPledge.value.month, amount_cents: cents, status: "pledged" },
  });
  newPledge.value = { month: "", amount: "" };
  await load();
}

async function updatePledge(p, amount) {
  const cents = Math.round(parseFloat(String(amount).replace(",", ".")) * 100);
  await client.patch(`/admin/monthly_pledges/${p.id}`, { monthly_pledge: { amount_cents: cents } });
  await load();
}

async function removePledge(p) {
  if (!confirm("Remover este mês?")) return;
  await client.delete(`/admin/monthly_pledges/${p.id}`);
  await load();
}

const pledges = computed(() => student.value?.pledges || []);
</script>

<template>
  <div v-if="student">
    <RouterLink :to="{ name: 'admin-students' }" class="muted">← Alunos</RouterLink>
    <div class="title-row" style="margin-top:.5rem">
      <h2>{{ student.full_name }}</h2>
    </div>

    <div class="grid cols-3">
      <div class="card stat"><span class="value">{{ brl(student.contributed_cents) }}</span><span class="label">Contribuído</span></div>
      <div class="card stat"><span class="value">{{ brl(student.expected_cents) }}</span><span class="label">Esperado</span></div>
      <div class="card stat">
        <span class="value" :class="student.balance_cents >= 0 ? 'positive' : 'negative'">{{ brl(student.balance_cents) }}</span>
        <span class="label">Saldo</span>
      </div>
    </div>

    <div class="card" style="margin-top:1.5rem">
      <h3>Valores prometidos por mês</h3>
      <form class="new-form" @submit.prevent="addPledge">
        <input v-model="newPledge.month" type="month" required />
        <input v-model="newPledge.amount" placeholder="Valor (ex: 110,00)" required />
        <button type="submit">Adicionar / atualizar mês</button>
      </form>
      <table>
        <thead><tr><th>Mês</th><th class="right">Prometido</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in pledges" :key="p.id">
            <td>{{ monthLabel(p.month) }}</td>
            <td class="right">
              <input
                style="width:120px; text-align:right"
                :value="(p.amount_cents / 100).toFixed(2)"
                @change="updatePledge(p, $event.target.value)"
              />
            </td>
            <td class="right"><button class="ghost" @click="removePledge(p)">✕</button></td>
          </tr>
        </tbody>
      </table>
      <p v-if="!pledges.length" class="muted center" style="padding:1rem">Nenhum mês cadastrado.</p>
    </div>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin: 1rem 0; padding: 1rem; background: #faf7f0; border-radius: 8px; }
</style>
