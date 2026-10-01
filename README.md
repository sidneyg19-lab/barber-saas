# Barber SaaS V1
Frontend premium React/Vite conectado ao Supabase Barber SaaS.

## Configuração
1. Copie `.env.example` para `.env`.
2. Coloque a Publishable Key que você já possui em `VITE_SUPABASE_PUBLISHABLE_KEY`.
3. `npm install`
4. `npm run dev`

## Produção / GitHub Pages
`npm run build` gera `dist/`. Publique o conteúdo via GitHub Pages/Actions.

## Segurança
Nunca coloque `service_role`, secret key ou senha do banco no frontend/GitHub.
O acesso aos dados é controlado pelas RLS do Supabase.

## Incluído
Login/cadastro, layout premium mobile-first, dashboard do dono/barbeiro, agenda, clientes, Drops e financeiro lendo as tabelas reais do Supabase. A estrutura SQL multi-tenant já criada no Supabase continua sendo a fonte de verdade.
