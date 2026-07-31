// Currency & date helpers (Brazilian Portuguese).

export function brl(cents, currency = "BRL") {
  const value = (cents || 0) / 100;
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency }).format(value);
}

const MONTHS = [
  "jan", "fev", "mar", "abr", "mai", "jun",
  "jul", "ago", "set", "out", "nov", "dez",
];

// "2024-08-01" -> "ago/24"
export function monthLabel(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  return `${MONTHS[d.getUTCMonth()]}/${String(d.getUTCFullYear()).slice(-2)}`;
}

// "2024-08-10" -> "10/08/2024"
export function dateLabel(dateStr) {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  return d.toLocaleDateString("pt-BR", { timeZone: "UTC" });
}

export function percent(ratio) {
  return `${((ratio || 0) * 100).toFixed(1)}%`;
}
