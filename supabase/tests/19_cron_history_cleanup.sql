begin;
select plan(5);
create extension if not exists pgtap with schema extensions;

select is((select count(*) from cron.job where jobname = 'cron-history-cleanup' and schedule = '17 3 * * *')::int, 1,
  'the cleanup job is scheduled once a day');

insert into cron.job_run_details (runid, jobid, database, username, command, status, start_time, end_time)
select 9000000000 + n, (select jobid from cron.job where jobname = 'notification-outbox'), 'postgres', 'postgres', 'select 1', 'succeeded',
       now() - age, now() - age
from (values (1, interval '8 days'), (2, interval '6 days'), (3, interval '1 minute')) as t(n, age);

select public.cleanup_cron_history();

select is((select count(*) from cron.job_run_details where command = 'select 1' and end_time < now() - interval '7 days')::int, 0,
  'runs older than the retention are deleted');
select is((select count(*) from cron.job_run_details where command = 'select 1')::int, 2,
  'newer runs are kept');
select ok(not has_function_privilege('authenticated', 'public.cleanup_cron_history()', 'execute'),
  'clients cannot run the cleanup');
select ok(not has_function_privilege('anon', 'public.cleanup_cron_history()', 'execute'),
  'visitors cannot run the cleanup');

select * from finish();
rollback;
