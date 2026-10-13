'use client';

import { SalonsTable } from '@/components/SalonsTable';
import { Card, PageHeader } from '@/components/ui';

export default function SalonsPage() {
  return (
    <>
      <PageHeader title="الصالونات" subtitle="كل الصالونات المسجلة وحالة اشتراكات حلاقيها" />
      <Card>
        <SalonsTable searchable />
      </Card>
    </>
  );
}
