-- BARBER CLUB V3.1 — LOJA, ESTOQUE E VENDAS
-- Execute uma vez após migration 001 + patch V2.
begin;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  sku text,
  description text,
  image_url text,
  cost_price numeric(12,2) not null default 0 check(cost_price >= 0),
  sale_price numeric(12,2) not null check(sale_price >= 0),
  stock_quantity numeric(12,3) not null default 0 check(stock_quantity >= 0),
  min_stock numeric(12,3) not null default 0 check(min_stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id, sku)
);

create table if not exists public.product_sales (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete set null,
  seller_professional_id uuid references public.professionals(id) on delete set null,
  status text not null default 'paid' check(status in ('pending','paid','cancelled','refunded')),
  payment_method text not null check(payment_method in ('cash','pix','debit_card','credit_card','wallet_credit','voucher','other')),
  subtotal numeric(12,2) not null default 0 check(subtotal >= 0),
  discount_amount numeric(12,2) not null default 0 check(discount_amount >= 0),
  total_amount numeric(12,2) not null default 0 check(total_amount >= 0),
  seller_commission_rate numeric(7,3) not null default 0 check(seller_commission_rate >= 0),
  seller_commission_amount numeric(12,2) not null default 0 check(seller_commission_amount >= 0),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.product_sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.product_sales(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  quantity numeric(12,3) not null check(quantity > 0),
  unit_cost numeric(12,2) not null default 0 check(unit_cost >= 0),
  unit_price numeric(12,2) not null check(unit_price >= 0),
  total_price numeric(12,2) not null check(total_price >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  sale_id uuid references public.product_sales(id) on delete set null,
  type text not null check(type in ('initial','purchase','sale','adjustment_in','adjustment_out','return')),
  quantity_delta numeric(12,3) not null,
  unit_cost numeric(12,2),
  note text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists products_org_active_idx on public.products(organization_id,active);
create index if not exists product_sales_org_created_idx on public.product_sales(organization_id,created_at desc);
create index if not exists inventory_product_created_idx on public.inventory_movements(product_id,created_at desc);

alter table public.products enable row level security;
alter table public.product_sales enable row level security;
alter table public.product_sale_items enable row level security;
alter table public.inventory_movements enable row level security;

do $$ declare t text; begin
  foreach t in array array['products','product_sales','inventory_movements'] loop
    execute format('drop policy if exists %I on public.%I', t||'_staff_select',t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_org_member(organization_id))',t||'_staff_select',t);
    execute format('drop policy if exists %I on public.%I', t||'_staff_insert',t);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_org_member(organization_id))',t||'_staff_insert',t);
    execute format('drop policy if exists %I on public.%I', t||'_staff_update',t);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id))',t||'_staff_update',t);
    execute format('drop policy if exists %I on public.%I', t||'_admin_delete',t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.has_org_role(organization_id,array[''owner'',''manager'']))',t||'_admin_delete',t);
  end loop;
end $$;

drop policy if exists product_sale_items_staff_select on public.product_sale_items;
create policy product_sale_items_staff_select on public.product_sale_items for select to authenticated using (
 exists(select 1 from public.product_sales s where s.id=sale_id and public.is_org_member(s.organization_id))
);
drop policy if exists product_sale_items_staff_insert on public.product_sale_items;
create policy product_sale_items_staff_insert on public.product_sale_items for insert to authenticated with check (
 exists(select 1 from public.product_sales s where s.id=sale_id and public.is_org_member(s.organization_id))
);

create or replace function public.register_product_sale(
 p_organization_id uuid, p_unit_id uuid, p_customer_id uuid, p_seller_professional_id uuid,
 p_payment_method text, p_discount numeric, p_items jsonb
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_uid uuid:=auth.uid(); v_sale uuid; v_sub numeric:=0; v_total numeric:=0; v_comm_rate numeric:=0; v_comm numeric:=0;
 item jsonb; v_prod products%rowtype; v_qty numeric; v_line numeric;
begin
 if v_uid is null or not public.is_org_member(p_organization_id) then raise exception 'Sem acesso à organização'; end if;
 if jsonb_array_length(coalesce(p_items,'[]'::jsonb))=0 then raise exception 'Venda sem itens'; end if;
 if p_payment_method not in ('cash','pix','debit_card','credit_card','wallet_credit','voucher','other') then raise exception 'Forma de pagamento inválida'; end if;
 for item in select * from jsonb_array_elements(p_items) loop
   v_qty:=coalesce((item->>'quantity')::numeric,0); if v_qty<=0 then raise exception 'Quantidade inválida'; end if;
   select * into v_prod from products where id=(item->>'product_id')::uuid and organization_id=p_organization_id and active for update;
   if not found then raise exception 'Produto inválido'; end if;
   if v_prod.stock_quantity < v_qty then raise exception 'Estoque insuficiente para %',v_prod.name; end if;
   v_sub:=v_sub+(v_prod.sale_price*v_qty);
 end loop;
 v_total:=greatest(v_sub-coalesce(p_discount,0),0);
 if p_seller_professional_id is not null then
   select case when commission_type='percentage' then commission_value else 0 end into v_comm_rate
   from professionals where id=p_seller_professional_id and organization_id=p_organization_id;
 end if;
 v_comm:=round(v_total*coalesce(v_comm_rate,0)/100,2);
 insert into product_sales(organization_id,unit_id,customer_id,seller_professional_id,payment_method,subtotal,discount_amount,total_amount,seller_commission_rate,seller_commission_amount,created_by)
 values(p_organization_id,p_unit_id,p_customer_id,p_seller_professional_id,p_payment_method,v_sub,coalesce(p_discount,0),v_total,coalesce(v_comm_rate,0),v_comm,v_uid) returning id into v_sale;
 for item in select * from jsonb_array_elements(p_items) loop
   v_qty:=(item->>'quantity')::numeric;
   select * into v_prod from products where id=(item->>'product_id')::uuid for update;
   v_line:=v_prod.sale_price*v_qty;
   insert into product_sale_items(sale_id,product_id,product_name,quantity,unit_cost,unit_price,total_price) values(v_sale,v_prod.id,v_prod.name,v_qty,v_prod.cost_price,v_prod.sale_price,v_line);
   update products set stock_quantity=stock_quantity-v_qty,updated_at=now() where id=v_prod.id;
   insert into inventory_movements(organization_id,product_id,sale_id,type,quantity_delta,unit_cost,note,created_by) values(p_organization_id,v_prod.id,v_sale,'sale',-v_qty,v_prod.cost_price,'Venda balcão',v_uid);
 end loop;
 insert into payments(organization_id,unit_id,customer_id,method,status,amount,paid_at,external_reference,notes,created_by)
 values(p_organization_id,p_unit_id,p_customer_id,p_payment_method,'paid',v_total,now(),'product_sale:'||v_sale::text,'Venda de produtos',v_uid);
 insert into cash_entries(organization_id,unit_id,type,amount,description,created_by) values(p_organization_id,p_unit_id,'income',v_total,'Venda de produtos #'||substr(v_sale::text,1,8),v_uid);
 return jsonb_build_object('ok',true,'sale_id',v_sale,'total',v_total,'commission',v_comm);
end $$;
grant execute on function public.register_product_sale(uuid,uuid,uuid,uuid,text,numeric,jsonb) to authenticated;

create or replace function public.adjust_product_stock(p_product_id uuid,p_quantity_delta numeric,p_note text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_org uuid; v_new numeric; begin
 select organization_id into v_org from products where id=p_product_id for update;
 if v_org is null or not public.is_org_member(v_org) then raise exception 'Sem acesso'; end if;
 update products set stock_quantity=stock_quantity+p_quantity_delta,updated_at=now() where id=p_product_id and stock_quantity+p_quantity_delta>=0 returning stock_quantity into v_new;
 if v_new is null then raise exception 'Ajuste deixaria estoque negativo'; end if;
 insert into inventory_movements(organization_id,product_id,type,quantity_delta,note,created_by) values(v_org,p_product_id,case when p_quantity_delta>=0 then 'adjustment_in' else 'adjustment_out' end,p_quantity_delta,p_note,v_uid);
 return jsonb_build_object('ok',true,'stock_quantity',v_new);
end $$;
grant execute on function public.adjust_product_stock(uuid,numeric,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists product_images_public_read on storage.objects;
create policy product_images_public_read on storage.objects for select using(bucket_id='product-images');
drop policy if exists product_images_staff_insert on storage.objects;
create policy product_images_staff_insert on storage.objects for insert to authenticated with check(bucket_id='product-images' and public.is_org_member(((storage.foldername(name))[1])::uuid));
drop policy if exists product_images_staff_update on storage.objects;
create policy product_images_staff_update on storage.objects for update to authenticated using(bucket_id='product-images' and public.is_org_member(((storage.foldername(name))[1])::uuid)) with check(bucket_id='product-images' and public.is_org_member(((storage.foldername(name))[1])::uuid));
drop policy if exists product_images_staff_delete on storage.objects;
create policy product_images_staff_delete on storage.objects for delete to authenticated using(bucket_id='product-images' and public.has_org_role(((storage.foldername(name))[1])::uuid,array['owner','manager']));

commit;
