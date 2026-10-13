'use client';

import { useState } from 'react';

import { errorMessage } from '@/lib/errors';
import { formatPhone } from '@/lib/phone';
import { supabase } from '@/lib/supabase';
import type { AdminBarber } from '@/lib/types';

import { PlanFields, PlansState, useActivePlans, usePlanForm } from './ActivateDialog';
import { LocationPicker } from './LocationPicker';
import { Button, ErrorNote, Modal, useToast } from './ui';

export function ApproveDialog({ barber, onClose, onDone }: { barber: AdminBarber; onClose: () => void; onDone: () => void }) {
  const { notify } = useToast();
  const [position, setPosition] = useState<{ lat: number | null; lng: number | null }>({ lat: barber.latitude, lng: barber.longitude });
  const [savedPosition, setSavedPosition] = useState(position);
  const [withPlan, setWithPlan] = useState(true);
  const plans = useActivePlans();
  const form = usePlanForm(plans.data);
  const [busy, setBusy] = useState<'pin' | 'approve' | null>(null);
  const [error, setError] = useState<string | null>(null);

  const pinChanged = position.lat !== savedPosition.lat || position.lng !== savedPosition.lng;

  async function savePin(): Promise<boolean> {
    if (position.lat == null || position.lng == null) return true;
    const { error: pinError } = await supabase().rpc('admin_set_salon_location', {
      p_salon_id: barber.salon_id,
      p_latitude: position.lat,
      p_longitude: position.lng,
    });
    if (pinError) {
      setError(errorMessage(pinError));
      return false;
    }
    setSavedPosition(position);
    return true;
  }

  async function onSavePin() {
    setBusy('pin');
    setError(null);
    if (await savePin()) notify('تم حفظ موقع الصالون');
    setBusy(null);
  }

  async function approve() {
    setBusy('approve');
    setError(null);
    if (pinChanged && !(await savePin())) {
      setBusy(null);
      return;
    }
    const { error: approveError } = withPlan
      ? await supabase().rpc('activate_subscription', form.args(barber.id))
      : await supabase().rpc('approve_barber', { p_barber_id: barber.id });
    setBusy(null);
    if (approveError) {
      setError(errorMessage(approveError));
      return;
    }
    notify(withPlan ? `تم تفعيل ${barber.display_name} واشتراكه` : `تم اعتماد ${barber.display_name}`);
    onDone();
    onClose();
  }

  return (
    <Modal title={`تفعيل ${barber.display_name}`} onClose={onClose} wide>
      <div className="flex flex-col gap-5">
        <dl className="grid grid-cols-3 gap-4 text-[14px]">
          <div>
            <dt className="text-caption text-ink-3">الهاتف</dt>
            <dd dir="ltr" className="text-start font-semibold text-ink">{formatPhone(barber.phone)}</dd>
          </div>
          <div>
            <dt className="text-caption text-ink-3">الصالون</dt>
            <dd className="font-semibold text-ink">{barber.salon_name}</dd>
          </div>
          <div>
            <dt className="text-caption text-ink-3">المنطقة</dt>
            <dd className="font-semibold text-ink">
              {barber.area_name}، {barber.city_name}
              {barber.address ? ` · ${barber.address}` : ''}
            </dd>
          </div>
        </dl>

        <div className="flex flex-col gap-2">
          <h3 className="text-h3 text-ink">موقع الصالون على الخريطة</h3>
          <p className="text-caption text-ink-3">اضغط على الخريطة أو اسحب الدبوس لتصحيح الموقع. يؤثر التعديل على الصالون كله.</p>
          <LocationPicker latitude={position.lat} longitude={position.lng} onChange={(lat, lng) => setPosition({ lat, lng })} />
          <div className="flex items-center justify-between gap-3">
            <span dir="ltr" data-testid="coordinates" className="text-caption text-ink-3">
              {position.lat != null && position.lng != null ? `${position.lat.toFixed(5)}, ${position.lng.toFixed(5)}` : 'لا يوجد موقع محدد'}
            </span>
            <Button variant="secondary" size="sm" busy={busy === 'pin'} disabled={!pinChanged} onClick={onSavePin}>
              حفظ الموقع
            </Button>
          </div>
        </div>

        <div className="flex flex-col gap-4 rounded-card bg-bg p-4">
          <label className="flex items-center gap-3 text-[15px] font-semibold text-ink">
            <input type="checkbox" className="size-5 accent-blue-900" checked={withPlan} onChange={(e) => setWithPlan(e.target.checked)} />
            تفعيل الاشتراك الآن (دفع نقداً)
          </label>
          {withPlan && (
            <PlansState plans={plans}>
              <PlanFields form={form} />
            </PlansState>
          )}
        </div>

        {error && <ErrorNote message={error} />}
        <div className="flex gap-3">
          <Button size="lg" className="flex-1" busy={busy === 'approve'} disabled={withPlan && !form.ready} onClick={approve}>
            {withPlan ? 'تفعيل وتحديد الباقة' : 'اعتماد بدون اشتراك'}
          </Button>
          <Button variant="secondary" size="lg" onClick={onClose}>
            إلغاء
          </Button>
        </div>
      </div>
    </Modal>
  );
}
