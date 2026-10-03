-- BARBER CLUB V4 PREMIUM — PATCH INCREMENTAL
-- Execute UMA VEZ após V3.1. Preserva dados existentes.
begin;

-- Permissões das tabelas da loja (corrige instalações V3.1 antigas)
grant select,insert,update,delete on table public.products,public.product_sales,public.product_sale_items to authenticated;

do $$ begin
  if to_regclass('public.inventory_movements') is not null then
    execute 'grant select,insert,update,delete on table public.inventory_movements to authenticated';
  end if;
end $$;

-- Snapshot de comissão do atendimento: mudança futura no profissional não altera histórico.
alter table public.appointments add column if not exists commission_rate_snapshot numeric(7,3) not null default 0;
alter table public.appointments add column if not exists commission_amount numeric(12,2) not null default 0;

create or replace function public.snapshot_appointment_commission()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_type text; v_value numeric:=0; v_total numeric:=0;
begin
  if new.status='completed' and coalesce(old.status,'')<>'completed' then
    select commission_type,coalesce(commission_value,0) into v_type,v_value from public.professionals where id=new.professional_id;
    select coalesce(sum(total_price),0) into v_total from public.appointment_services where appointment_id=new.id;
    new.commission_rate_snapshot:=case when v_type='percentage' then v_value else 0 end;
    new.commission_amount:=case when v_type='percentage' then round(v_total*v_value/100,2) when v_type='fixed' then v_value else 0 end;
  end if;
  return new;
end $$;
drop trigger if exists trg_snapshot_appointment_commission on public.appointments;
create trigger trg_snapshot_appointment_commission before update of status on public.appointments for each row execute function public.snapshot_appointment_commission();

-- Criação atômica do agendamento. Valida serviço x profissional, jornada e sobreposição pela duração.
create or replace function public.create_appointment_v4(
 p_organization_id uuid,p_unit_id uuid,p_customer_id uuid,p_professional_id uuid,p_service_id uuid,p_start_at timestamptz
) returns uuid language plpgsql security definer set search_path=public as $$
declare
 v_uid uuid:=auth.uid(); v_service public.services%rowtype; v_end timestamptz; v_id uuid;
 v_local_start timestamp; v_local_end timestamp; v_weekday int; v_ok boolean;
begin
 if v_uid is null or not public.is_org_member(p_organization_id) then raise exception 'Sem acesso à organização'; end if;
 if not exists(select 1 from public.customers where id=p_customer_id and organization_id=p_organization_id and active) then raise exception 'Cliente inválido'; end if;
 if not exists(select 1 from public.professionals where id=p_professional_id and organization_id=p_organization_id and active) then raise exception 'Profissional inválido'; end if;
 select * into v_service from public.services where id=p_service_id and organization_id=p_organization_id and active;
 if not found then raise exception 'Serviço inválido'; end if;
 if exists(select 1 from public.professional_services where service_id=p_service_id) and not exists(select 1 from public.professional_services where service_id=p_service_id and professional_id=p_professional_id and active) then raise exception 'Este profissional não realiza este serviço'; end if;
 v_end:=p_start_at + make_interval(mins=>v_service.duration_minutes);
 -- Piloto Brasil: regra operacional em America/Sao_Paulo. Pode virar timezone da organização futuramente.
 v_local_start:=p_start_at at time zone 'America/Sao_Paulo'; v_local_end:=v_end at time zone 'America/Sao_Paulo'; v_weekday:=extract(dow from v_local_start)::int;
 select exists(select 1 from public.professional_availability pa where pa.organization_id=p_organization_id and pa.unit_id=p_unit_id and pa.professional_id=p_professional_id and pa.active and pa.weekday=v_weekday and v_local_start::time>=pa.start_time and v_local_end::time<=pa.end_time and v_local_start::date=v_local_end::date) into v_ok;
 if not v_ok then raise exception 'Horário fora da jornada do profissional'; end if;
 if exists(select 1 from public.appointments a where a.professional_id=p_professional_id and a.organization_id=p_organization_id and a.status not in ('cancelled','no_show') and tstzrange(a.start_at,a.end_at,'[)') && tstzrange(p_start_at,v_end,'[)')) then raise exception 'Esse profissional já possui atendimento que conflita com este horário'; end if;
 insert into public.appointments(organization_id,unit_id,customer_id,professional_id,start_at,end_at,created_by,source,status)
 values(p_organization_id,p_unit_id,p_customer_id,p_professional_id,p_start_at,v_end,v_uid,'reception','scheduled') returning id into v_id;
 insert into public.appointment_services(appointment_id,service_id,service_name,quantity,unit_price,duration_minutes,total_price)
 values(v_id,v_service.id,v_service.name,1,v_service.price,v_service.duration_minutes,v_service.price);
 return v_id;
end $$;
grant execute on function public.create_appointment_v4(uuid,uuid,uuid,uuid,uuid,timestamptz) to authenticated;

-- Base Web Push: uma assinatura por dispositivo, isolada por organização/usuário.
create table if not exists public.push_subscriptions (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 endpoint text not null,
 p256dh text not null,
 auth text not null,
 user_agent text,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,endpoint)
);
alter table public.push_subscriptions enable row level security;
drop policy if exists push_subscriptions_own_select on public.push_subscriptions;
create policy push_subscriptions_own_select on public.push_subscriptions for select to authenticated using(user_id=auth.uid() and public.is_org_member(organization_id));
drop policy if exists push_subscriptions_own_insert on public.push_subscriptions;
create policy push_subscriptions_own_insert on public.push_subscriptions for insert to authenticated with check(user_id=auth.uid() and public.is_org_member(organization_id));
drop policy if exists push_subscriptions_own_update on public.push_subscriptions;
create policy push_subscriptions_own_update on public.push_subscriptions for update to authenticated using(user_id=auth.uid() and public.is_org_member(organization_id)) with check(user_id=auth.uid() and public.is_org_member(organization_id));
drop policy if exists push_subscriptions_own_delete on public.push_subscriptions;
create policy push_subscriptions_own_delete on public.push_subscriptions for delete to authenticated using(user_id=auth.uid());
grant select,insert,update,delete on public.push_subscriptions to authenticated;

commit;
