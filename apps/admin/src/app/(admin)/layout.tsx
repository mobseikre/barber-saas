import type { ReactNode } from 'react';

import { AdminGate } from '@/components/AuthProvider';
import { Sidebar } from '@/components/Sidebar';
import { ToastProvider } from '@/components/ui';

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <AdminGate>
      <ToastProvider>
        <div className="flex min-h-screen">
          <Sidebar />
          <main className="min-w-0 flex-1 px-5 py-8 lg:px-10">{children}</main>
        </div>
      </ToastProvider>
    </AdminGate>
  );
}
