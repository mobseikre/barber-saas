'use client';

import { useRouter } from 'next/navigation';
import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';

import { supabase } from '@/lib/supabase';

interface Counts {
  pending: number;
}

interface AdminSession {
  counts: Counts;
  refreshCounts: () => void;
  signOut: () => Promise<void>;
}

const AdminContext = createContext<AdminSession | null>(null);

export const useAdmin = () => {
  const value = useContext(AdminContext);
  if (!value) throw new Error('useAdmin outside AdminGate');
  return value;
};

export function AdminGate({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [counts, setCounts] = useState<Counts>({ pending: 0 });

  const refreshCounts = useCallback(() => {
    supabase()
      .from('admin_barbers')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending')
      .then(({ count }) => setCounts({ pending: count ?? 0 }));
  }, []);

  const signOut = useCallback(async () => {
    await supabase().auth.signOut();
    router.replace('/login');
  }, [router]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase().auth.getSession();
      if (!data.session) {
        router.replace('/login');
        return;
      }
      const { data: isAdmin } = await supabase().rpc('is_admin');
      if (cancelled) return;
      if (isAdmin !== true) {
        await supabase().auth.signOut();
        router.replace('/login?denied=1');
        return;
      }
      setReady(true);
      refreshCounts();
    })();

    const { data: listener } = supabase().auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_OUT') router.replace('/login');
    });
    return () => {
      cancelled = true;
      listener.subscription.unsubscribe();
    };
  }, [router, refreshCounts]);

  if (!ready) return <div className="min-h-screen bg-bg" aria-busy="true" />;
  return <AdminContext.Provider value={{ counts, refreshCounts, signOut }}>{children}</AdminContext.Provider>;
}
