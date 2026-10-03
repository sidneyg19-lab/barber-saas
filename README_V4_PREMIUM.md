# Barber Club V4 Premium — Piloto

## Ordem de atualização
1. Faça backup do projeto/Supabase antes do piloto.
2. No Supabase > SQL Editor, execute `barber_saas_v4_patch.sql` uma única vez.
3. Copie os arquivos deste projeto sobre a pasta local clonada pelo GitHub Desktop (não apague a pasta `.git`).
4. No GitHub Desktop confira as alterações, faça commit: `V4 Premium - piloto` e clique em **Push origin**.
5. Aguarde o GitHub Actions/Pages publicar e faça recarga completa nos celulares.

## O que esta entrega já inclui
- PWA real: manifest, ícones, service worker, modo standalone.
- Logout acessível no mobile por menu de conta.
- Agendamento atômico com validação de jornada, duração e sobreposição.
- Snapshot de comissão de serviços no momento da conclusão.
- Base de Web Push (`push_subscriptions`) com RLS; envio real exige VAPID/backend e será a etapa de ativação do push.
- Cliente clicável, perfil, histórico e edição.
- Edição de serviço/profissional/horário e seleção Adicionar todos/Remover todos.
- Edição de produto, inclusive foto e ajuste de estoque.
- Financeiro em formato BI com Hoje / 7 dias / Mês / Ano, serviços, produtos, despesas, comissões, líquido e ticket médio.

## Testes obrigatórios do piloto
- João 09:00–18:00: rejeitar 19:00 e rejeitar serviço que termine depois das 18:00.
- Rejeitar sobreposição, inclusive horários diferentes dentro do mesmo atendimento.
- Criar/concluir atendimento e conferir pagamento + comissão no BI.
- Editar cliente, serviço, profissional, horário e produto; confirmar atualização sem F5.
- Venda de produto: baixar estoque e refletir no financeiro.
- Android: instalar como app e abrir sem barra do Chrome.
- iPhone: Adicionar à Tela de Início e abrir em modo app.
- Mobile: abrir menu e sair da conta.

## Push
A estrutura de assinatura foi preparada, mas o push real não deve ser ativado sem configurar chaves VAPID e um emissor seguro (Edge Function/backend). A chave privada nunca deve ir para o frontend.

## V4.1 — auditoria de cliques da Home
- O card **Agenda Inteligente** agora é uma ação real e abre a central de Drops.
- A própria Home explica que o sistema não cria desconto automaticamente: o proprietário escolhe serviço, profissional, horário e preço.
- As linhas de **Próximos atendimentos** agora levam para a Agenda, eliminando a seta sem ação.
- Regra de UX do piloto: elementos com aparência de ação não podem permanecer como decoração/dead-click.
