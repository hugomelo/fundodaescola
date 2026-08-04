<script setup>
import { ref, computed } from "vue";
import { useRoute, RouterLink, useRouter } from "vue-router";
import client from "../api/client";

const route = useRoute();
const router = useRouter();

const token = computed(() => String(route.query.token || ""));
const password = ref("");
const confirmation = ref("");
const error = ref("");
const done = ref(false);
const busy = ref(false);

async function submit() {
  error.value = "";
  if (!token.value) {
    error.value = "Link inválido. Solicite um novo e-mail de redefinição.";
    return;
  }
  if (password.value !== confirmation.value) {
    error.value = "As senhas não coincidem.";
    return;
  }
  if (password.value.length < 6) {
    error.value = "A senha deve ter pelo menos 6 caracteres.";
    return;
  }

  busy.value = true;
  try {
    await client.post("/auth/reset_password", {
      token: token.value,
      password: password.value,
      password_confirmation: confirmation.value,
    });
    done.value = true;
    setTimeout(() => router.push({ name: "login" }), 2500);
  } catch (e) {
    const code = e.response?.data?.error;
    if (code === "invalid_or_expired_token") {
      error.value = "Este link expirou ou é inválido. Solicite um novo.";
    } else if (code === "password_mismatch") {
      error.value = "As senhas não coincidem.";
    } else {
      error.value = e.response?.data?.details?.join(" ") || "Não foi possível redefinir a senha.";
    }
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="login-wrap">
    <div class="card login-card">
      <h1>Nova senha</h1>
      <p class="muted">Escolha uma nova senha para a sua conta.</p>

      <form v-if="!done" @submit.prevent="submit">
        <label>Nova senha</label>
        <input v-model="password" type="password" autocomplete="new-password" required minlength="6" />
        <label>Confirmar senha</label>
        <input v-model="confirmation" type="password" autocomplete="new-password" required minlength="6" />
        <p v-if="error" class="negative">{{ error }}</p>
        <button type="submit" :disabled="busy">{{ busy ? "Salvando..." : "Salvar senha" }}</button>
      </form>

      <div v-else class="done">
        <p class="positive">Senha atualizada. Redirecionando para o login…</p>
      </div>

      <p class="back">
        <RouterLink :to="{ name: 'login' }">← Voltar ao login</RouterLink>
        ·
        <RouterLink :to="{ name: 'forgot-password' }">Pedir novo link</RouterLink>
      </p>
    </div>
  </div>
</template>

<style scoped>
.login-wrap { min-height: 100vh; display: grid; place-items: center; padding: 1rem; }
.login-card { width: 100%; max-width: 360px; text-align: center; }
h1 { margin: 0.3rem 0 0; font-size: 1.35rem; }
form { display: flex; flex-direction: column; gap: 0.4rem; margin-top: 1.2rem; text-align: left; }
label { font-size: 0.85rem; color: var(--muted); margin-top: 0.4rem; }
button { margin-top: 1rem; }
.done { margin-top: 1.2rem; }
.back { margin-top: 1.25rem; font-size: 0.9rem; }
</style>
