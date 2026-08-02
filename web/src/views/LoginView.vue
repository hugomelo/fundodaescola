<script setup>
import { ref } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "../stores/auth";

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();

const email = ref("");
const password = ref("");
const error = ref("");
const busy = ref(false);

async function submit() {
  error.value = "";
  busy.value = true;
  try {
    await auth.login(email.value, password.value);
    router.push(route.query.redirect || "/");
  } catch (e) {
    error.value = e.response?.status === 401 ? "E-mail ou senha inválidos." : "Não foi possível entrar. Tente novamente.";
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="login-wrap">
    <div class="card login-card">
      <div class="logo">🌾</div>
      <h1>Fundo da Escola</h1>
      <p class="muted">Fundo de viagens pedagógicas</p>
      <form @submit.prevent="submit">
        <label>E-mail</label>
        <input v-model="email" type="email" autocomplete="email" required placeholder="voce@exemplo.com" />
        <label>Senha</label>
        <input v-model="password" type="password" autocomplete="current-password" required />
        <p v-if="error" class="negative">{{ error }}</p>
        <button type="submit" :disabled="busy">{{ busy ? "Entrando..." : "Entrar" }}</button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.login-wrap { min-height: 100vh; display: grid; place-items: center; padding: 1rem; }
.login-card { width: 100%; max-width: 360px; text-align: center; }
.logo { font-size: 2.5rem; }
h1 { margin: 0.3rem 0 0; }
form { display: flex; flex-direction: column; gap: 0.4rem; margin-top: 1.2rem; text-align: left; }
label { font-size: 0.85rem; color: var(--muted); margin-top: 0.4rem; }
button { margin-top: 1rem; }
</style>
