import { createRouter, createWebHashHistory } from "vue-router";
import { useAuthStore } from "../stores/auth";

const routes = [
  { path: "/login", name: "login", component: () => import("../views/LoginView.vue"), meta: { public: true } },
  { path: "/", name: "home", component: () => import("../views/HomeView.vue") },
  { path: "/aluno/:id", name: "student", component: () => import("../views/ParentDashboardView.vue"), props: true },
  {
    path: "/admin",
    component: () => import("../views/admin/AdminLayout.vue"),
    meta: { admin: true },
    children: [
      { path: "", redirect: { name: "admin-dashboard" } },
      { path: "painel", name: "admin-dashboard", component: () => import("../views/admin/DashboardView.vue") },
      { path: "pagamentos", name: "admin-payments", component: () => import("../views/admin/PaymentsView.vue") },
      { path: "eventos", name: "admin-events", component: () => import("../views/admin/EventsView.vue") },
      { path: "alunos", name: "admin-students", component: () => import("../views/admin/StudentsView.vue") },
      { path: "alunos/:id", name: "admin-student", component: () => import("../views/admin/StudentPledgesView.vue"), props: true },
      { path: "mapeamentos", name: "admin-mappings", component: () => import("../views/admin/MappingsView.vue") },
      { path: "rendimentos", name: "admin-investments", component: () => import("../views/admin/InvestmentsView.vue") },
      { path: "usuarios", name: "admin-users", component: () => import("../views/admin/UsersView.vue") },
      { path: "configuracoes", name: "admin-settings", component: () => import("../views/admin/SettingsView.vue") },
    ],
  },
];

const router = createRouter({ history: createWebHashHistory(), routes });

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  if (to.meta.public) return true;
  if (!auth.isAuthenticated) return { name: "login", query: { redirect: to.fullPath } };
  if (!auth.user) {
    try { await auth.fetchMe(); } catch { auth.logout(); return { name: "login" }; }
  }
  if (to.meta.admin && !auth.isAdmin) return { name: "home" };
  return true;
});

export default router;
