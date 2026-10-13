'use client';

import { useState, type ReactNode } from 'react';

import { Button, Modal } from './ui';

export function ConfirmDialog({ title, children, confirmLabel, danger, onConfirm, onClose }: {
  title: string;
  children?: ReactNode;
  confirmLabel: string;
  danger?: boolean;
  onConfirm: () => Promise<void>;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState(false);

  async function confirm() {
    setBusy(true);
    try {
      await onConfirm();
    } finally {
      setBusy(false);
    }
    onClose();
  }

  return (
    <Modal title={title} onClose={onClose}>
      <div className="flex flex-col gap-5">
        {children && <div className="text-[15px] text-ink-2">{children}</div>}
        <div className="flex gap-3">
          <Button variant={danger ? 'accent' : 'primary'} size="lg" className="flex-1" busy={busy} onClick={confirm}>
            {confirmLabel}
          </Button>
          <Button variant="secondary" size="lg" onClick={onClose}>
            إلغاء
          </Button>
        </div>
      </div>
    </Modal>
  );
}
