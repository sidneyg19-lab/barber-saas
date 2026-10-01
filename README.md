# Barber Club V2

V2 mobile-first do SaaS multi-tenant para barbearias.

## Antes do deploy
1. Execute `barber_saas_v2_patch.sql` no SQL Editor do mesmo projeto Supabase.
2. Em Authentication > URL Configuration, use como Site URL o endereço do GitHub Pages do projeto e adicione o mesmo endereço em Redirect URLs.
3. No GitHub, mantenha os repository secrets `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY`.
4. Substitua os arquivos do repositório por esta V2. O workflow `.github/workflows/deploy.yml` publica automaticamente.

## Fluxos implementados
- Login/cadastro com retorno para o site publicado.
- Onboarding do primeiro owner, organização, unidade e profissional principal via RPC segura.
- Dashboard real.
- Clientes: cadastro, busca e métricas.
- Agenda: criação com cliente/profissional/serviço e bloqueio de conflito pelo banco; conclusão via `complete_appointment`.
- Drops: criação real de campanha + slot promocional.
- Financeiro: recebimentos/despesas do mês e registro de despesa.
- Multi-tenant respeitando RLS existente.
- Mobile-first e navegação inferior estilo app.

## Próximas integrações externas
Push notification/WhatsApp e gateway de pagamento exigem provedores/credenciais externos e não são simulados nesta V2.
