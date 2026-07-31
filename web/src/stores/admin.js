import { defineStore } from "pinia";
import client from "../api/client";

export const useAdminStore = defineStore("admin", {
  state: () => ({
    grades: [],
    currentGradeId: Number(localStorage.getItem("cc_admin_grade")) || null,
    loaded: false,
  }),
  getters: {
    currentGrade: (s) => s.grades.find((g) => g.id === s.currentGradeId) || s.grades[0] || null,
  },
  actions: {
    async loadGrades() {
      const { data } = await client.get("/admin/grades");
      this.grades = data.grades;
      if (!this.currentGradeId && this.grades.length) this.setGrade(this.grades[0].id);
      this.loaded = true;
    },
    setGrade(id) {
      this.currentGradeId = Number(id);
      localStorage.setItem("cc_admin_grade", String(id));
    },
  },
});
