<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { brl, monthLabel } from "../../utils/format";

const props = defineProps({ id: { type: [Number, String], required: true } });
const student = ref(null);
const newPledge = ref({ month: "", amount: "" });
const nameForm = ref({ full_name: "", display_name: "" });
const enrollment = ref({ from: "", until: "" });
const savingName = ref(false);
const savingEnrollment = ref(false);
const nameError = ref("");
const nameSaved = ref(false);

function toMonthInput(value) {
  return value ? String(value).slice(0, 7) : "";
}

async function load() {
  const { data } = await client.get(`/admin/students/${props.id}`);
  student.value = data.student;
  nameForm.value = {
    full_name: data.student.full_name || "",
    display_name: data.student.display_name || "",
  };
  enrollment.value = {
    from: toMonthInput(data.student.enrolled_from),
    until: toMonthInput(data.student.enrolled_until),
  };
}
watch(() => props.id, load, { immediate: true });

async function saveName() {
  savingName.value = true;
  nameError.value = "";
  nameSaved.value = false;
  try {
    await client.patch(`/admin/students/${props.id}`, {
      student: {
        full_name: nameForm.value.full_name.trim(),
        display_name: nameForm.value.display_name.trim() || null,
      },
    });
    await load();
    nameSaved.value = true;
  } catch (e) {
    nameError.value = e.response?.data?.details?.join(", ") || "Não foi possível salvar o nome.";
  } finally {
    savingName.value = false;
  }
}

async function saveEnrollment() {
  savingEnrollment.value = true;
  try {
    await client.patch(`/admin/students/${props.id}`, {
      student: {
        enrolled_from: enrollment.value.from ? `${enrollment.value.from}-01` : null,
        enrolled_until: enrollment.value.until ? `${enrollment.value.until}-01` : null,
      },
    });
    await load();
  } finally {
    savingEnrollment.value = false;
  }
}

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
      <h3>Nome</h3>
      <form class="new-form" @submit.prevent="saveName">
        <label>Nome completo
          <input v-model="nameForm.full_name" required style="min-width:220px" />
        </label>
        <label>Nome de exibição
          <input v-model="nameForm.display_name" placeholder="Opcional (ex.: primeiro nome)" style="min-width:160px" />
        </label>
        <button type="submit" :disabled="savingName">{{ savingName ? "Salvando…" : "Salvar nome" }}</button>
        <span v-if="nameSaved" class="badge green">Salvo</span>
        <span v-if="nameError" class="negative">{{ nameError }}</span>
      </form>
    </div>

    <div class="card" style="margin-top:1.5rem">
      <h3>Período de matrícula</h3>
      <p class="muted" style="margin:.2rem 0 .8rem">
        O esperado acumula só dentro deste período. Deixe a saída em branco se o aluno ainda está na turma.
      </p>
      <form class="new-form" @submit.prevent="saveEnrollment">
        <label>Início <input v-model="enrollment.from" type="month" /></label>
        <label>Saída <input v-model="enrollment.until" type="month" /></label>
        <button type="submit" :disabled="savingEnrollment">{{ savingEnrollment ? "Salvando…" : "Salvar período" }}</button>
      </form>
    </div>

    <div class="card" style="margin-top:1.5rem">
      <h3>Valores prometidos</h3>
      <p class="muted" style="margin:.2rem 0 .8rem">
        Cada valor vale <strong>a partir do mês informado</strong> e permanece até o próximo.
        Ex.: ago/24 = R$130 e jul/25 = R$175 → cobra R$130 de ago/24 a jun/25 e R$175 de jul/25 em diante.
        Basta cadastrar os meses em que o valor muda.
      </p>
      <form class="new-form" @submit.prevent="addPledge">
        <input v-model="newPledge.month" type="month" required />
        <input v-model="newPledge.amount" placeholder="Valor (ex: 110,00)" required />
        <button type="submit">Adicionar / atualizar</button>
      </form>
      <table>
        <thead><tr><th>Vigente a partir de</th><th class="right">Prometido / mês</th><th></th></tr></thead>
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
.new-form label { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); gap: 0.2rem; }
</style>
