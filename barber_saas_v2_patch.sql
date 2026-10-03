-- BARBER CLUB V2 - PATCH FUNCIONAL
-- Execute UMA VEZ no SQL Editor do Supabase depois da migration 001.
-- Corrige onboarding multi-tenant e habilita upload de avatares.

begin;

create or replace function public.create_barbershop_onboarding(
  p_name text,
  p_owner_name text,
  p_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid;
  v_unit uuid;
  v_member uuid;
  v_prof uuid;
  v_slug text;
begin
  if v_uid is null then raise exception 'Usuário não autenticado'; end if;
  if nullif(trim(p_name),'') is null then raise exception 'Informe o nome da barbearia'; end if;
  if exists(select 1 from organization_members where user_id=v_uid and active) then
    select organization_id into v_org from organization_members where user_id=v_uid and active order by created_at limit 1;
    return jsonb_build_object('ok',true,'already_exists',true,'organization_id',v_org);
  end if;

  update profiles set full_name=coalesce(nullif(trim(p_owner_name),''),full_name), phone=coalesce(nullif(trim(p_phone),''),phone) where id=v_uid;
  v_slug := lower(regexp_replace(unaccent_safe(p_name), '[^a-zA-Z0-9]+', '-', 'g'));
  v_slug := trim(both '-' from v_slug) || '-' || substr(replace(v_uid::text,'-',''),1,6);

  insert into organizations(name,slug,phone,created_by) values(trim(p_name),v_slug,nullif(trim(p_phone),''),v_uid) returning id into v_org;
  insert into units(organization_id,name,slug,phone) values(v_org,'Principal','principal',nullif(trim(p_phone),'')) returning id into v_unit;
  insert into organization_members(organization_id,user_id,role) values(v_org,v_uid,'owner') returning id into v_member;
  insert into member_units(member_id,unit_id) values(v_member,v_unit);
  insert into professionals(organization_id,user_id,display_name,phone,is_featured,commission_type,commission_value)
    values(v_org,v_uid,coalesce(nullif(trim(p_owner_name),''),'Barbeiro principal'),nullif(trim(p_phone),''),true,'percentage',0) returning id into v_prof;
  insert into professional_units(professional_id,unit_id) values(v_prof,v_unit);

  insert into service_categories(organization_id,name,sort_order) values(v_org,'Barbearia',1);
  insert into audit_logs(organization_id,user_id,action,entity_type,entity_id,metadata)
    values(v_org,v_uid,'onboarding_created','organization',v_org::text,jsonb_build_object('unit_id',v_unit,'professional_id',v_prof));

  return jsonb_build_object('ok',true,'organization_id',v_org,'unit_id',v_unit,'professional_id',v_prof);
end;
$$;

-- helper sem depender da extensão unaccent
create or replace function public.unaccent_safe(p_text text)
returns text language sql immutable as $$
select translate(coalesce(p_text,''),
'ÁÀÃÂÄáàãâäÉÈÊËéèêëÍÌÎÏíìîïÓÒÕÔÖóòõôöÚÙÛÜúùûüÇçÑñ',
'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn');
$$;

-- recria onboarding agora que helper existe (Postgres resolve no runtime, mantido por clareza)

grant execute on function public.create_barbershop_onboarding(text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects for select using (bucket_id='avatars');
drop policy if exists "avatars_auth_insert" on storage.objects;
create policy "avatars_auth_insert" on storage.objects for insert to authenticated with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "avatars_auth_update" on storage.objects;
create policy "avatars_auth_update" on storage.objects for update to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text) with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "avatars_auth_delete" on storage.objects;
create policy "avatars_auth_delete" on storage.objects for delete to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

commit;
