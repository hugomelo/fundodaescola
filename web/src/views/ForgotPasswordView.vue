<script setup>
import { ref } from "vue";
import { RouterLink } from "vue-router";
import client from "../api/client";

const email = ref("");
const error = ref("");
const sent = ref(false);
const busy = ref(false);

async function submit() {
  error.value = "";
  busy.value = true;
  try {
    await client.post("/auth/forgot_password", { email: email.value });
    sent.value = true;
  } catch {
    error.value = "Não foi possível enviar. Tente novamente.";
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="login-wrap">
    <div class="card login-card">
      <h1>Esqueci minha senha</h1>
      <p class="muted">Informe seu e-mail e enviaremos um link para redefinir a senha.</p>

      <form v-if="!sent" @submit.prevent="submit">
        <label>E-mail</label>
        <input v-model="email" type="email" autocomplete="email" required placeholder="voce@exemplo.com" />
        <p v-if="error" class="negative">{{ error }}</p>
        <button type="submit" :disabled="busy">{{ busy ? "Enviando..." : "Enviar link" }}</button>
      </form>

      <div v-else class="done">
        <p>
          Se o e-mail estiver cadastrado, você receberá as instruções em breve.
          Verifique também a caixa de spam.
        </p>
      </div>

      <p class="back">
        <RouterLink :to="{ name: 'login' }">← Voltar ao login</RouterLink>
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
.done { margin-top: 1.2rem; text-align: left; color: var(--ink); line-height: 1.5; }
.back { margin-top: 1.25rem; font-size: 0.9rem; }
</style>
