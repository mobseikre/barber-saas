'use client';

import { Pencil, Plus, Trash2 } from 'lucide-react';
import { useEffect, useState } from 'react';

import { ConfirmDialog } from '@/components/Confirm';
import { Button, Card, Empty, ErrorNote, Input, Loading, PageHeader, useToast } from '@/components/ui';
import { must } from '@/lib/db';
import { errorMessage } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import type { Area, City } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

type Kind = 'cities' | 'areas';
type Item = City | Area;

function NameRow({ item, subtitle, selected, onSelect, onSave, onDelete }: {
  item: Item;
  subtitle?: string;
  selected?: boolean;
  onSelect?: () => void;
  onSave: (name: string) => Promise<boolean>;
  onDelete: () => void;
}) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(item.name);

  useEffect(() => setName(item.name), [item.name]);

  async function save() {
    if (!name.trim()) return;
    if (await onSave(name.trim())) setEditing(false);
  }

  return (
    <li className={`flex items-center gap-2 rounded-ctl border px-3 py-2 ${selected ? 'border-blue-900 bg-blue-100' : 'border-line-soft'}`}>
      {editing ? (
        <>
          <Input value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && save()} aria-label="الاسم" className="h-10" autoFocus />
          <Button size="sm" onClick={save} disabled={!name.trim()}>
            حفظ
          </Button>
          <Button size="sm" variant="secondary" onClick={() => setEditing(false)}>
            إلغاء
          </Button>
        </>
      ) : (
        <>
          {onSelect ? (
            <button type="button" onClick={onSelect} className="flex-1 py-1 text-start" aria-pressed={selected}>
              <span className="font-bold text-ink">{item.name}</span>
              {subtitle && <span className="text-caption text-ink-3"> · {subtitle}</span>}
            </button>
          ) : (
            <span className="flex-1 py-1 font-bold text-ink">{item.name}</span>
          )}
          <button type="button" onClick={() => setEditing(true)} aria-label={`تعديل ${item.name}`} className="flex size-9 items-center justify-center rounded-small border border-line text-ink hover:border-blue-900">
            <Pencil size={16} />
          </button>
          <button type="button" onClick={onDelete} aria-label={`حذف ${item.name}`} className="flex size-9 items-center justify-center rounded-small border border-line text-danger-fg hover:border-danger-fg">
            <Trash2 size={16} />
          </button>
        </>
      )}
    </li>
  );
}

function AddRow({ label, onAdd }: { label: string; onAdd: (name: string) => Promise<boolean> }) {
  const [name, setName] = useState('');

  async function add() {
    if (name.trim() && (await onAdd(name.trim()))) setName('');
  }

  return (
    <div className="flex gap-2">
      <Input value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && add()} placeholder={label} aria-label={label} />
      <Button size="lg" variant="accent" disabled={!name.trim()} onClick={add} aria-label={`إضافة: ${label}`}>
        <Plus size={18} /> إضافة
      </Button>
    </div>
  );
}

export default function LocationsPage() {
  const { notify } = useToast();
  const [cityId, setCityId] = useState<string>();
  const [deleting, setDeleting] = useState<{ kind: Kind; item: Item } | null>(null);

  const data = useAsync(async () => {
    const [cities, areas] = await Promise.all([
      must<City[]>(supabase().from('cities').select('id,name,sort_order').order('sort_order').order('name')),
      must<Area[]>(supabase().from('areas').select('id,city_id,name,sort_order').order('sort_order').order('name')),
    ]);
    return { cities, areas };
  }, []);

  const cities = data.data?.cities ?? [];
  const selected = cities.find((c) => c.id === cityId) ?? cities[0];
  const areas = (data.data?.areas ?? []).filter((a) => a.city_id === selected?.id);

  async function write(action: PromiseLike<{ error: unknown }>, success: string): Promise<boolean> {
    const { error } = await action;
    if (error) {
      notify(errorMessage(error), 'error');
      return false;
    }
    notify(success);
    data.reload();
    return true;
  }

  const nextOrder = (items: Item[]) => items.reduce((max, i) => Math.max(max, i.sort_order), 0) + 1;

  if (data.loading && !data.data) return <Loading />;
  if (data.error) return <ErrorNote message={data.error} onRetry={data.reload} />;

  return (
    <>
      <PageHeader title="المدن والمناطق" subtitle="تظهر في تسجيل الحلاقين وفي تصفية الزبائن للصالونات" />
      <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-2">
        <Card className="flex flex-col gap-4">
          <h2 className="text-h2 text-ink">المدن</h2>
          <AddRow label="اسم مدينة جديدة" onAdd={(name) => write(supabase().from('cities').insert({ name, sort_order: nextOrder(cities) }), 'تمت إضافة المدينة')} />
          {cities.length === 0 ? (
            <Empty>لا توجد مدن</Empty>
          ) : (
            <ul className="flex flex-col gap-2">
              {cities.map((city) => (
                <NameRow
                  key={city.id}
                  item={city}
                  subtitle={`المناطق: ${(data.data?.areas ?? []).filter((a) => a.city_id === city.id).length}`}
                  selected={city.id === selected?.id}
                  onSelect={() => setCityId(city.id)}
                  onSave={(name) => write(supabase().from('cities').update({ name }).eq('id', city.id), 'تم تعديل المدينة')}
                  onDelete={() => setDeleting({ kind: 'cities', item: city })}
                />
              ))}
            </ul>
          )}
        </Card>
        <Card className="flex flex-col gap-4">
          <h2 className="text-h2 text-ink">{selected ? `مناطق ${selected.name}` : 'المناطق'}</h2>
          {selected && <AddRow label="اسم منطقة جديدة" onAdd={(name) => write(supabase().from('areas').insert({ city_id: selected.id, name, sort_order: nextOrder(areas) }), 'تمت إضافة المنطقة')} />}
          {areas.length === 0 ? (
            <Empty>لا توجد مناطق</Empty>
          ) : (
            <ul className="flex flex-col gap-2">
              {areas.map((area) => (
                <NameRow
                  key={area.id}
                  item={area}
                  onSave={(name) => write(supabase().from('areas').update({ name }).eq('id', area.id), 'تم تعديل المنطقة')}
                  onDelete={() => setDeleting({ kind: 'areas', item: area })}
                />
              ))}
            </ul>
          )}
        </Card>
      </div>
      {deleting && (
        <ConfirmDialog
          title={`حذف ${deleting.item.name}؟`}
          confirmLabel="حذف"
          danger
          onConfirm={async () => {
            await write(supabase().from(deleting.kind).delete().eq('id', deleting.item.id), 'تم الحذف');
          }}
          onClose={() => setDeleting(null)}
        >
          {deleting.kind === 'cities' ? 'تُحذف معها كل مناطقها. لا يمكن الحذف إذا كانت مرتبطة بصالونات.' : 'لا يمكن الحذف إذا كانت مرتبطة بصالونات.'}
        </ConfirmDialog>
      )}
    </>
  );
}
