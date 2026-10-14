-- The every-10-seconds outbox job writes a cron.job_run_details row per run; keep a week of them

create function public.cron_history_retention() returns interval
language sql immutable as $$ select interval '7 days' $$;

create function public.cleanup_cron_history() returns void
language sql security definer set search_path = public as $$
  delete from cron.job_run_details where end_time < now() - cron_history_retention()
$$;

revoke execute on function public.cron_history_retention() from public, anon, authenticated;
revoke execute on function public.cleanup_cron_history() from public, anon, authenticated;

select cron.schedule('cron-history-cleanup', '17 3 * * *', $$ select public.cleanup_cron_history() $$);
