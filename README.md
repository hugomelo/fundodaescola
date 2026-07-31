# 🌾 Colheita Coletiva

Ferramenta web para acompanhar o **fundo de viagens** de uma turma da escola Waldorf.
Cada responsável vê **apenas** as contribuições do(s) seu(s) filho(s) — quanto já
contribuiu e quanto está adiantado ou faltando — além do panorama geral (agregado,
não identificado) de quanto a turma já arrecadou frente à meta.

Suporta **múltiplas turmas** com administradores por turma.

## Arquitetura

| Camada | Tecnologia | Onde roda |
|---|---|---|
| Frontend | Vue 3 + Vite (`web/`) | GitHub Pages |
| Backend | Rails 8 API-only (`api/`) | VPS (`fundo-api.prout.io`) |
| Banco | PostgreSQL | VPS (Docker) |
| Auth | JWT (Bearer) | — |

### Modelo de dados
- **Grade** (turma) — meta (`target_total_cents`), ano letivo.
- **Student** — pertence a uma turma, com início/fim de matrícula.
- **MonthlyPledge** — valor prometido por aluno por mês.
- **Payment** — transação do extrato (`student_contribution` ou `event`; sinal do valor = entrada/saída).
- **PayerMapping** — associa o nome do pagador no extrato a um aluno ou a "Evento".
- **InvestmentEntry** — rendimento mensal da aplicação (lançado manualmente).
- **User** — `super_admin` / `grade_admin` / `parent`.
- **StudentAccess** — vínculo responsável ↔ aluno (permite vários responsáveis e irmãos).

**Fórmulas**
- Contribuído do aluno = Σ pagamentos de contribuição do aluno.
- Esperado = Σ prometidos dos meses matriculados até o mês atual.
- Saldo do aluno = contribuído − esperado (+ adiantado / − atrasado).
- Arrecadado da turma = Σ pagamentos (contribuições + eventos, com sinal) + Σ rendimentos.
- Progresso = arrecadado ÷ meta.

## Desenvolvimento local

Pré-requisitos: Ruby 3.4.x (rbenv), Node 22+, Docker.

### 1. Banco (Postgres em Docker)
```bash
docker run -d --name colheita-pg \
  -e POSTGRES_USER=colheita -e POSTGRES_PASSWORD=colheita \
  -e POSTGRES_DB=colheita_development -p 5433:5432 postgres:17
```

### 2. API
```bash
cd api
bundle install
bin/rails db:prepare          # cria e migra (usa api/.env)
bin/rails import:spreadsheet \ # importa a planilha (opcional)
  GRADE_NAME="Turma da Nina" SCHOOL_NAME="Escola Waldorf" TARGET_TOTAL=80000
bin/rails db:seed             # cria usuários de exemplo
bin/rails s -p 3001
```
Config local em `api/.env` (porta do banco 5433, `JWT_SECRET`, `CORS_ORIGINS`).

Usuários de exemplo (senha `colheita123`):
`admin@colheita.local` (admin geral), `coordenador@colheita.local` (coordenador),
`responsavel@colheita.local` (responsável).

### 3. Frontend
```bash
cd web
npm install
npm run dev   # http://localhost:5173  (usa web/.env -> VITE_API_BASE_URL)
```

## Importação da planilha

O importador lê os dois CSVs em `api/db/import_data/` (exportados do Google Sheets):
- `payments.csv` (aba de pagamentos) — fonte da lista de alunos e de todas as transações.
- `students.csv` (aba por aluno) — valores **prometidos** por mês + matrícula.

Nomes divergentes entre as abas são reconciliados por correspondência de tokens.
Pagamentos são deduplicados por `external_ref` (idempotente).

Importação incremental do extrato pelo painel admin:
**Administração → Pagamentos → Importar CSV do banco**. O importador aceita o
extrato real do banco (separado por `;`, com cabeçalho e descrições como
"Pix recebido de <nome>") — o prefixo é removido para recuperar o nome do pagador.
Pagadores conhecidos são mapeados automaticamente para o aluno predominante; os
demais ficam como "Não identificados" para associação manual.

### Eventos e fila de revisão

O extrato não distingue uma contribuição de uma compra feita num evento (ex.: um
pedaço de bolo). Para resolver isso, cadastre as **datas dos eventos** em
**Administração → Eventos**. Todo pagamento que cai num dia de evento — mais os
pagadores não identificados — é marcado para **revisão**:

- O importador ainda faz o melhor palpite (a contribuição mensal recorrente continua
  funcionando), mas sinaliza os casos ambíguos.
- Em **Pagamentos → Revisar** você confirma cada um: mantém como contribuição do
  aluno ou troca para **Evento** num clique. Qualquer edição limpa o sinal de revisão.

### Movimentações de investimento

Transferências internas entre a conta corrente e a conta investimento (ex.:
"Transferência enviada para conta investimento", aplicações e resgates) são
**ignoradas** na importação — o dinheiro continua fazendo parte do fundo, apenas
muda de conta. O **rendimento** (juros) é lançado à parte em
**Administração → Rendimentos**.


## Endpoints principais

- `POST /api/auth/login`, `GET /api/me`
- `GET /api/students/:id/summary`, `GET /api/students/:id/payments`
- `GET /api/grades/:id/overview` (agregado, não identificado)
- `GET/POST/PATCH/DELETE /api/admin/...` (grades, students, monthly_pledges,
  payments + `import`, payer_mappings, investment_entries, users, e
  `grades/:id/dashboard`)

## Deploy

### Backend (VPS)
1. Aponte o DNS `fundo-api.prout.io` para o VPS.
2. Copie `.env.production.example` para `.env` e preencha os segredos
   (`openssl rand -hex 64` para `SECRET_KEY_BASE` e `JWT_SECRET`; defina `CORS_ORIGINS`
   com a URL do GitHub Pages).
3. Suba a stack (Postgres + API + Caddy/TLS):
   ```bash
   docker compose up -d --build
   ```
   As migrações rodam automaticamente no boot (`rails db:prepare`).

### Frontend (GitHub Pages)
`.github/workflows/pages.yml` faz build de `web/` e publica no Pages a cada push em `main`.
Ajuste `VITE_API_BASE_URL` e `VITE_BASE_PATH` (nome do repositório) no workflow se necessário,
e habilite **Settings → Pages → Source: GitHub Actions**.
