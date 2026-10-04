# Barber Sygoi V5 — preparação do piloto

## Ordem de atualização
1. No Supabase SQL Editor, execute `barber_saas_v5_piloto_patch.sql` uma única vez, depois do patch V4.
2. Substitua os arquivos do repositório pelos arquivos desta pasta.
3. Commit + push para `main` e aguarde o GitHub Actions ficar verde.
4. No PWA instalado, feche/reabra o app. Se o manifesto/ícone antigo persistir, remova a instalação antiga e instale novamente.

## Mudanças principais
- Barber Sygoi é a marca padrão da plataforma/PWA.
- Dentro da sessão, nome e logo são do tenant; celebrações também usam o nome da barbearia.
- Gestão > Identidade permite nome, URL da logo e cor de destaque por organização.
- Safe-area para iPhone e menu mobile de conta/logout.
- Agenda: editar/reagendar/cancelar; conclusão só a partir do horário marcado, protegida também no banco.
- Status de atendimento traduzidos.
- Home não chama atendimentos concluídos de “próximos”.
- Agenda Inteligente detecta espaços livres nos próximos 7 dias cruzando jornada e agenda e permite transformar a sugestão em Drop.
- Drop valida horário futuro e desconto real; campanha é criada com período válido para não violar `campaigns_check`.
- Base de Web Push permanece preparada; ativação do envio real fica para a próxima etapa após os testes funcionais.

## Testes antes do Push Notification
- Identidade de duas organizações diferentes não deve vazar entre tenants.
- Criar, editar, reagendar e cancelar agendamento.
- Tentar concluir atendimento futuro: deve bloquear no frontend e no banco.
- Concluir atendimento já iniciado: pagamento e comissão devem refletir no Financeiro.
- Criar conflito de agenda e horário fora da jornada: ambos devem bloquear.
- Abrir Agenda Inteligente e validar sugestões contra horários livres reais.
- Publicar Drop sugerido e Drop manual; preço promocional deve ser menor que o normal.
- Testar logout e cabeçalho no iPhone/Android.
