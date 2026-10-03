# Barber Club V3

Entrega integrada sobre a V2.

## Novidades
- Gestão > Serviços: cadastro com preço, duração, pontos e vínculo aos profissionais.
- Gestão > Equipe: cadastro de profissionais e comissão.
- Gestão > Horários: disponibilidade semanal por profissional.
- Agenda: criação funcional e conclusão com registro de pagamento.
- Fidelidade: usa `complete_appointment` existente para pontos, visitas, gasto e comissão.
- Drops: usa o catálogo de serviços/profissionais.
- Microinterações premium: celebração curta ao agendar/concluir.
- Mobile-first reforçado.

## Banco
Use o schema `barber_saas_migration_001.sql` + `barber_saas_v2_patch.sql` já aplicados. Esta V3 reutiliza as tabelas existentes, sem recriar o banco.

## Publicação
Substitua os arquivos do repositório pelo conteúdo desta pasta preservando os Secrets do GitHub já configurados e aguarde o workflow do GitHub Pages.
