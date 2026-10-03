# Barber Club V3.1

Inclui a V3 + Loja/Estoque/Vendas:
- catálogo de produtos com foto (câmera/galeria), custo, preço, SKU, estoque e estoque mínimo;
- venda no balcão com cliente opcional, barbeiro/vendedor, desconto e forma de pagamento;
- baixa de estoque transacional via RPC;
- entrada automática no financeiro e caixa;
- comissão de venda de produto baseada no percentual do barbeiro;
- alerta de estoque baixo;
- histórico de vendas e itens;
- mantém serviços, agenda, clientes, Drops, fidelidade e financeiro.

## Instalação
1. O projeto deve já ter `migration 001` e `barber_saas_v2_patch.sql` aplicados.
2. Execute `barber_saas_v3_1_patch.sql` no SQL Editor do Supabase.
3. Suba os arquivos desta pasta no repositório, preservando `src/`.
4. Mantenha as secrets `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` no GitHub Actions.
5. Faça o deploy e teste no celular.
