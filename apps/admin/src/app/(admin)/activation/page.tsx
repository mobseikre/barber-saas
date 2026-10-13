'use client';

import { useState } from 'react';

import { PendingQueue } from '@/components/PendingQueue';
import { Card, Chips, PageHeader } from '@/components/ui';

export default function ActivationPage() {
  const [status, setStatus] = useState<'pending' | 'rejected'>('pending');

  return (
    <>
      <PageHeader title="طلبات التفعيل" subtitle="حلاقون سجّلوا حديثاً بانتظار موافقة الإدارة" />
      <Card className="flex flex-col gap-4">
        <Chips
          value={status}
          onChange={setStatus}
          options={[
            { value: 'pending', label: 'بانتظار التفعيل' },
            { value: 'rejected', label: 'المرفوضون' },
          ]}
        />
        <PendingQueue status={status} />
      </Card>
    </>
  );
}
