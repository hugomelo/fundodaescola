<script setup>
import { brl, monthLabel, dateLabel } from "../utils/format";

defineProps({
  rows: { type: Array, required: true },
  currency: { type: String, default: "BRL" },
  bankUpdatedThrough: { type: [String, Date], default: null },
  sectionId: { type: String, default: null },
});
</script>

<template>
  <div class="card" :id="sectionId || undefined" :class="{ 'section-anchor': !!sectionId }">
    <div class="title-row">
      <h2>Mês a mês</h2>
      <p v-if="bankUpdatedThrough" class="muted bank-disclaimer">
        Extrato bancário atualizado até {{ dateLabel(bankUpdatedThrough) }}
      </p>
    </div>
    <table>
      <thead>
        <tr>
          <th>Mês</th>
          <th class="right">Prometido</th>
          <th class="right">Contribuído</th>
          <th>Contribuinte</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in rows" :key="r.month">
          <td>{{ monthLabel(r.month) }}</td>
          <td class="right">{{ r.pledged_cents != null ? brl(r.pledged_cents, currency) : "—" }}</td>
          <td class="right">{{ brl(r.contributed_cents, currency) }}</td>
          <td class="contributors">
            <template v-if="r.payments?.length">
              <div
                v-for="p in r.payments"
                :key="p.id"
                class="contributor"
                :class="{ refund: p.amount_cents < 0 }"
              >
                <span class="payer">{{ p.description }}</span>
                <span class="meta">
                  <span class="muted">{{ dateLabel(p.paid_on) }}</span>
                  <span class="amount" :class="{ negative: p.amount_cents < 0 }">
                    {{ brl(p.amount_cents, currency) }}
                    <template v-if="p.amount_cents < 0"> (estorno)</template>
                  </span>
                </span>
              </div>
            </template>
            <span v-else class="muted">—</span>
          </td>
          <td>
            <span
              v-if="r.pledged_cents != null && r.contributed_cents >= r.pledged_cents"
              class="badge green"
            >
              ok
            </span>
          </td>
        </tr>
      </tbody>
    </table>
    <p v-if="!rows.length" class="muted center" style="padding:1rem">Nenhum mês cadastrado.</p>
    <p class="muted note">
      O valor contribuído é o total líquido dos pagamentos daquele mês (créditos menos estornos).
      Pagamentos adiantados aparecem no mês em que caíram na conta, mas o saldo considera o total acumulado.
    </p>
  </div>
</template>

<style scoped>
.note { margin-top: 1rem; font-size: 0.85rem; }
.bank-disclaimer {
  margin: 0;
  font-size: 0.85rem;
  text-align: right;
}
.section-anchor { scroll-margin-top: 4.5rem; }
.contributors { font-size: 0.9rem; }
.contributor {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}
.contributor + .contributor { margin-top: 0.45rem; }
.contributor .meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem 0.6rem;
  font-size: 0.8rem;
}
.contributor .amount { white-space: nowrap; font-variant-numeric: tabular-nums; }
.contributor.refund .payer { color: var(--muted); }
@media (max-width: 560px) {
  .bank-disclaimer { text-align: left; }
}
</style>
