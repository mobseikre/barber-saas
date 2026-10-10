insert into public.cities (name, sort_order) values
  ('طرابلس', 1),
  ('بنغازي', 2),
  ('مصراتة', 3);

insert into public.areas (city_id, name, sort_order)
select c.id, a.name, a.sort_order
from public.cities c
join (values
  ('طرابلس', 'حي الأندلس', 1),
  ('طرابلس', 'قرقارش', 2),
  ('طرابلس', 'سوق الجمعة', 3),
  ('بنغازي', 'الفويهات', 1)
) as a (city, name, sort_order) on a.city = c.name;

insert into public.service_catalog (code, name_ar, description_ar, default_duration_min, sort_order) values
  ('haircut', 'قص شعر', 'قص وتصفيف كلاسيكي أو حديث', 30, 1),
  ('beard', 'لحية', 'تحديد وتهذيب اللحية بالموس', 20, 2),
  ('kids', 'أطفال', 'قص شعر للأطفال حتى 12 سنة', 20, 3),
  ('facial', 'تنظيف كامل', 'تنظيف بشرة، بخار وماسك', 40, 4),
  ('vip', 'VIP', 'شعر + لحية + تنظيف + مساج', 75, 5),
  ('groom', 'باقة العريس', 'تجهيز كامل ليوم الزفاف', 120, 6);
