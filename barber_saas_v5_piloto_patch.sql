-- BARBER SYGOI V5 — PATCH PILOTO
-- Execute UMA VEZ após V4. Preserva os dados existentes.
begin;

-- Identidade visual por tenant.
alter table public.organizations add column if not exists brand_accent_color text not null default '#d3a94f';

-- Segurança operacional: atendimento futuro nunca pode virar concluído,
-- mesmo que alguém contorne o botão do frontend.
create or replace function public.guard_appointment_completion_v5()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.status='completed' and coalesce(old.status,'')<>'completed' and now() < new.start_at then
    raise exception 'Este atendimento ainda não começou. Só pode ser concluído a partir do horário agendado';
  end if;
  return new;
end $$;
drop trigger if exists trg_guard_appointment_completion_v5 on public.appointments;
create trigger trg_guard_appointment_completion_v5
before update of status on public.appointments
for each row execute function public.guard_appointment_completion_v5();

-- Reagendamento/edição com as mesmas regras de jornada e conflito da criação.
create or replace function public.update_appointment_v5(
 p_appointment_id uuid,p_customer_id uuid,p_professional_id uuid,p_service_id uuid,p_start_at timestamptz
) returns uuid language plpgsql security definer set search_path=public as $$
declare
 v_uid uuid:=auth.uid(); v_appt public.appointments%rowtype; v_service public.services%rowtype;
 v_end timestamptz; v_local_start timestamp; v_local_end timestamp; v_weekday int; v_ok boolean;
begin
 select * into v_appt from public.appointments where id=p_appointment_id;
 if not found then raise exception 'Agendamento não encontrado'; end if;
 if v_uid is null or not public.is_org_member(v_appt.organization_id) then raise exception 'Sem acesso à organização'; end if;
 if v_appt.status in ('completed','cancelled') then raise exception 'Este atendimento não pode mais ser alterado'; end if;
 if not exists(select 1 from public.customers where id=p_customer_id and organization_id=v_appt.organization_id and active) then raise exception 'Cliente inválido'; end if;
 if not exists(select 1 from public.professionals where id=p_professional_id and organization_id=v_appt.organization_id and active) then raise exception 'Profissional inválido'; end if;
 select * into v_service from public.services where id=p_service_id and organization_id=v_appt.organization_id and active;
 if not found then raise exception 'Serviço inválido'; end if;
 if exists(select 1 from public.professional_services where service_id=p_service_id)
    and not exists(select 1 from public.professional_services where service_id=p_service_id and professional_id=p_professional_id and active)
 then raise exception 'Este profissional não realiza este serviço'; end if;
 v_end:=p_start_at + make_interval(mins=>v_service.duration_minutes);
 v_local_start:=p_start_at at time zone 'America/Sao_Paulo';
 v_local_end:=v_end at time zone 'America/Sao_Paulo';
 v_weekday:=extract(dow from v_local_start)::int;
 select exists(select 1 from public.professional_availability pa where pa.organization_id=v_appt.organization_id and pa.unit_id=v_appt.unit_id and pa.professional_id=p_professional_id and pa.active and pa.weekday=v_weekday and v_local_start::time>=pa.start_time and v_local_end::time<=pa.end_time and v_local_start::date=v_local_end::date) into v_ok;
 if not v_ok then raise exception 'Horário fora da jornada do profissional'; end if;
 if exists(select 1 from public.appointments a where a.id<>p_appointment_id and a.professional_id=p_professional_id and a.organization_id=v_appt.organization_id and a.status not in ('cancelled','no_show') and tstzrange(a.start_at,a.end_at,'[)') && tstzrange(p_start_at,v_end,'[)')) then raise exception 'Esse profissional já possui atendimento que conflita com este horário'; end if;
 update public.appointments set customer_id=p_customer_id,professional_id=p_professional_id,start_at=p_start_at,end_at=v_end where id=p_appointment_id;
 delete from public.appointment_services where appointment_id=p_appointment_id;
 insert into public.appointment_services(appointment_id,service_id,service_name,quantity,unit_price,duration_minutes,total_price)
 values(p_appointment_id,v_service.id,v_service.name,1,v_service.price,v_service.duration_minutes,v_service.price);
 return p_appointment_id;
end $$;
grant execute on function public.update_appointment_v5(uuid,uuid,uuid,uuid,timestamptz) to authenticated;

create or replace function public.cancel_appointment_v5(p_appointment_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_status text;
begin
 select organization_id,status into v_org,v_status from public.appointments where id=p_appointment_id;
 if v_org is null then raise exception 'Agendamento não encontrado'; end if;
 if not public.is_org_member(v_org) then raise exception 'Sem acesso à organização'; end if;
 if v_status='completed' then raise exception 'Atendimento concluído não pode ser cancelado'; end if;
 update public.appointments set status='cancelled' where id=p_appointment_id;
end $$;
grant execute on function public.cancel_appointment_v5(uuid) to authenticated;

commit;
