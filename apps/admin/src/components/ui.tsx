'use client';

import { Check, Clock, AlertCircle, X, Loader2 } from 'lucide-react';
import { createContext, useCallback, useContext, useEffect, useId, useRef, useState, type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from 'react';

import { GENERIC_ERROR } from '@/lib/errors';
import type { BarberStatus, BookingStatus } from '@/lib/types';

const cx = (...parts: (string | false | null | undefined)[]) => parts.filter(Boolean).join(' ');

type ButtonVariant = 'primary' | 'accent' | 'secondary' | 'danger' | 'link';
const BUTTON_STYLES: Record<ButtonVariant, string> = {
  primary: 'bg-blue-900 text-white hover:bg-blue-pressed disabled:bg-blue-100 disabled:text-ink-3',
  accent: 'bg-red-pole text-white hover:bg-red-600 disabled:bg-blue-100 disabled:text-ink-3',
  secondary: 'bg-white text-blue-900 border-[1.5px] border-blue-900 disabled:border-line disabled:text-ink-3',
  danger: 'bg-white text-danger-fg border-[1.5px] border-line hover:border-danger-fg disabled:text-ink-3',
  link: 'bg-transparent text-red-700 hover:underline disabled:text-ink-3',
};

export function Button({
  variant = 'primary',
  size = 'md',
  busy,
  className,
  children,
  disabled,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: 'sm' | 'md' | 'lg'; busy?: boolean }) {
  const sizes = { sm: 'h-9 rounded-small px-3 text-[14px]', md: 'h-11 rounded-ctl px-4 text-[15px]', lg: 'h-[52px] rounded-ctl px-5 text-[16px]' };
  return (
    <button
      type="button"
      disabled={disabled || busy}
      className={cx(
        'inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap font-bold transition-colors disabled:cursor-not-allowed',
        variant === 'link' ? 'px-1 text-[15px]' : sizes[size],
        BUTTON_STYLES[variant],
        className,
      )}
      {...rest}
    >
      {busy && <Loader2 size={16} className="animate-spin" />}
      {children}
    </button>
  );
}

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return <section className={cx('rounded-card bg-surface p-5 shadow-card', className)}>{children}</section>;
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: ReactNode; actions?: ReactNode }) {
  return (
    <header className="mb-6 flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 className="text-h1 text-ink">{title}</h1>
        {subtitle && <p className="text-caption text-ink-3">{subtitle}</p>}
      </div>
      {actions}
    </header>
  );
}

export function Field({ label, error, children }: { label: string; error?: string | null; children: (id: string) => ReactNode }) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-[14px] font-semibold text-ink">
        {label}
      </label>
      {children(id)}
      {error && <p className="text-caption text-danger-fg">{error}</p>}
    </div>
  );
}

const CONTROL = 'h-[52px] w-full rounded-ctl border-[1.5px] bg-white px-4 text-[15px] text-ink outline-none placeholder:text-ink-3 focus:border-red-400 focus:shadow-ring';

export function Input({ invalid, className, ...rest }: InputHTMLAttributes<HTMLInputElement> & { invalid?: boolean }) {
  return <input className={cx(CONTROL, invalid ? 'border-danger-fg' : 'border-line', className)} {...rest} />;
}

export function Select({ className, children, ...rest }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select className={cx(CONTROL, 'border-line', className)} {...rest}>
      {children}
    </select>
  );
}

export function SearchInput({ value, onChange, placeholder }: { value: string; onChange: (value: string) => void; placeholder: string }) {
  return (
    <input
      type="search"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      aria-label={placeholder}
      className="h-11 w-full max-w-sm rounded-ctl border-[1.5px] border-line bg-white px-4 text-[15px] text-ink outline-none placeholder:text-ink-3 focus:border-red-400 focus:shadow-ring"
    />
  );
}

export function Chips<T extends string>({ options, value, onChange }: { options: { value: T; label: string }[]; value: T; onChange: (value: T) => void }) {
  return (
    <div className="flex flex-wrap gap-2" role="group">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          aria-pressed={option.value === value}
          onClick={() => onChange(option.value)}
          className={cx(
            'h-9 rounded-full border px-4 text-[14px] font-bold transition-colors',
            option.value === value ? 'border-blue-900 bg-blue-900 text-white' : 'border-line bg-white text-blue-900 hover:border-blue-900',
          )}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

const TONES = {
  info: 'bg-info-bg text-info-fg',
  success: 'bg-success-bg text-success-fg',
  warning: 'bg-warning-bg text-warning-fg',
  danger: 'bg-danger-bg text-danger-fg',
  neutral: 'bg-bg text-ink-2',
} as const;
export type Tone = keyof typeof TONES;

export function Badge({ tone, icon, children }: { tone: Tone; icon?: ReactNode; children: ReactNode }) {
  return (
    <span className={cx('inline-flex h-[30px] items-center gap-1.5 whitespace-nowrap rounded-badge px-3 text-[13px] font-bold', TONES[tone])}>
      {icon}
      {children}
    </span>
  );
}

export function Pill({ tone, children }: { tone: Tone; children: ReactNode }) {
  return <span className={cx('inline-flex h-6 items-center whitespace-nowrap rounded-badge px-2 text-[12px] font-bold', TONES[tone])}>{children}</span>;
}

const BOOKING_STATUS: Record<BookingStatus, { tone: Tone; label: string; icon: ReactNode }> = {
  confirmed: { tone: 'info', label: 'مؤكد', icon: <Clock size={14} /> },
  completed: { tone: 'success', label: 'مكتمل', icon: <Check size={14} /> },
  no_show: { tone: 'warning', label: 'لم يحضر', icon: <AlertCircle size={14} /> },
  cancelled: { tone: 'danger', label: 'ملغي', icon: <X size={14} /> },
};

export function BookingStatusBadge({ status }: { status: BookingStatus }) {
  const { tone, label, icon } = BOOKING_STATUS[status];
  return (
    <Badge tone={tone} icon={icon}>
      {label}
    </Badge>
  );
}

export type SubscriptionState = 'active' | 'ending' | 'expired' | 'none';

export function SubscriptionBadge({ state }: { state: SubscriptionState }) {
  const map = {
    active: { tone: 'success', label: 'مشترك' },
    ending: { tone: 'warning', label: 'ينتهي قريباً' },
    expired: { tone: 'warning', label: 'منتهي' },
    none: { tone: 'neutral', label: 'غير مشترك' },
  } as const;
  const { tone, label } = map[state];
  return (
    <Badge tone={tone} icon={<span className="size-1.5 rounded-full bg-current" />}>
      {label}
    </Badge>
  );
}

const BARBER_STATUS: Record<BarberStatus, { tone: Tone; label: string }> = {
  pending: { tone: 'info', label: 'بانتظار التفعيل' },
  active: { tone: 'success', label: 'نشط' },
  suspended: { tone: 'warning', label: 'موقوف' },
  rejected: { tone: 'danger', label: 'مرفوض' },
};

export function BarberStatusBadge({ status }: { status: BarberStatus }) {
  const { tone, label } = BARBER_STATUS[status];
  return <Badge tone={tone}>{label}</Badge>;
}

export function Table({ head, children, empty, compact }: { head: string[]; children: ReactNode; empty?: ReactNode; compact?: boolean }) {
  return (
    <div className="overflow-x-auto">
      <table className={cx('w-full border-collapse text-start', compact ? 'min-w-[520px]' : 'min-w-[640px]')}>
        <thead>
          <tr className="border-b border-line">
            {head.map((label, i) => (
              <th key={`${label}-${i}`} scope="col" className="px-3 py-3 text-start text-[13px] font-bold text-ink-2">
                {label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
      {empty}
    </div>
  );
}

export const Row = ({ children, highlight }: { children: ReactNode; highlight?: boolean }) => (
  <tr className={cx('border-b border-line-soft last:border-0', highlight && 'bg-bg')}>{children}</tr>
);
export const Cell = ({ children, className }: { children?: ReactNode; className?: string }) => (
  <td className={cx('px-3 py-3 align-middle text-[14px] text-ink-2', className)}>{children}</td>
);

export function Avatar({ name, muted }: { name: string; muted?: boolean }) {
  return (
    <span className={cx('flex size-10 shrink-0 items-center justify-center rounded-full text-[16px] font-extrabold', muted ? 'bg-line text-ink-3' : 'bg-blue-800 text-red-400')}>
      {Array.from(name.trim())[0]}
    </span>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="py-10 text-center text-[15px] text-ink-3">{children}</p>;
}

export function Loading() {
  return (
    <div className="flex justify-center py-10 text-ink-3" role="status" aria-label="جارٍ التحميل">
      <Loader2 className="animate-spin" />
    </div>
  );
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex items-center justify-between gap-4 rounded-ctl bg-danger-bg px-4 py-3 text-[14px] font-semibold text-danger-fg">
      <span>{message}</span>
      {onRetry && (
        <button type="button" onClick={onRetry} className="font-bold underline">
          إعادة المحاولة
        </button>
      )}
    </div>
  );
}

export function Modal({ title, onClose, children, wide, dismissible = true }: { title: string; onClose: () => void; children: ReactNode; wide?: boolean; dismissible?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => dismissible && e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    ref.current?.focus();
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose, dismissible]);

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-blue-950/50 p-4" onMouseDown={(e) => dismissible && e.target === e.currentTarget && onClose()}>
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className={cx('max-h-[92vh] w-full overflow-y-auto rounded-panel bg-white p-6 shadow-card outline-none', wide ? 'max-w-3xl' : 'max-w-md')}
      >
        <div className="mb-4 flex items-center justify-between gap-4">
          <h2 className="text-h2 text-ink">{title}</h2>
          <button type="button" onClick={onClose} aria-label="إغلاق" className="flex size-11 items-center justify-center rounded-ctl border border-line text-ink-2 hover:border-blue-900">
            <X size={20} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

interface ToastApi {
  notify: (message: string, tone?: 'success' | 'error') => void;
}
const ToastContext = createContext<ToastApi>({ notify: () => undefined });
export const useToast = () => useContext(ToastContext);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<{ message: string; tone: 'success' | 'error'; id: number } | null>(null);
  const notify = useCallback((message: string, tone: 'success' | 'error' = 'success') => {
    setToast({ message: message || GENERIC_ERROR, tone, id: Date.now() });
  }, []);
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 4500);
    return () => clearTimeout(timer);
  }, [toast]);

  return (
    <ToastContext.Provider value={{ notify }}>
      {children}
      {toast && (
        <div
          role={toast.tone === 'error' ? 'alert' : 'status'}
          className={cx(
            'fixed bottom-6 left-1/2 z-[1100] -translate-x-1/2 rounded-ctl px-5 py-3 text-[15px] font-bold shadow-card',
            toast.tone === 'error' ? 'bg-danger-fg text-white' : 'bg-blue-900 text-white',
          )}
        >
          {toast.message}
        </div>
      )}
    </ToastContext.Provider>
  );
}

export function subscriptionState(endsAt: string | null, endingWithinDays: number): SubscriptionState {
  if (!endsAt) return 'none';
  const remaining = new Date(endsAt).getTime() - Date.now();
  if (remaining <= 0) return 'expired';
  return remaining <= endingWithinDays * 86_400_000 ? 'ending' : 'active';
}
