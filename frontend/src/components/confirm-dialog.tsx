'use client';

import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';

export interface ConfirmOptions {
  title: string;
  message?: string;
  confirmLabel: string;
  cancelLabel?: string;
  /** Red confirm button, for removing or banning. */
  danger?: boolean;
}

type ConfirmFn = (options: ConfirmOptions) => Promise<boolean>;

const ConfirmContext = createContext<ConfirmFn | null>(null);

/**
 * The panel's "Are you sure?" box, in place of the browser's confirm():
 * `if (!(await confirm({ title, confirmLabel }))) return;`. A native
 * <dialog> opened with showModal() keeps focus inside and closes on Esc
 * (= Cancel).
 */
export function ConfirmProvider({ children }: { children: React.ReactNode }) {
  const [options, setOptions] = useState<ConfirmOptions | null>(null);
  const resolver = useRef<((ok: boolean) => void) | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);

  const confirm = useCallback<ConfirmFn>((next) => {
    resolver.current?.(false); // a second request cancels the first
    setOptions(next);
    return new Promise<boolean>((resolve) => {
      resolver.current = resolve;
    });
  }, []);

  useEffect(() => {
    if (options && !dialog.current?.open) dialog.current?.showModal();
  }, [options]);

  function finish(ok: boolean) {
    resolver.current?.(ok);
    resolver.current = null;
    dialog.current?.close();
    setOptions(null);
  }

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      <dialog
        ref={dialog}
        className="confirm-dialog"
        aria-labelledby="confirm-dialog-title"
        onCancel={(e) => {
          e.preventDefault();
          finish(false);
        }}
        onClick={(e) => {
          // A click on the backdrop (the dialog itself, outside the box) cancels.
          if (e.target === e.currentTarget) finish(false);
        }}
      >
        {options && (
          <div className="confirm-dialog-box">
            <h2 id="confirm-dialog-title">{options.title}</h2>
            {options.message && <p className="muted">{options.message}</p>}
            <div className="confirm-dialog-actions">
              <button type="button" className="btn" onClick={() => finish(false)} autoFocus>
                {options.cancelLabel ?? 'Cancel'}
              </button>
              <button
                type="button"
                className={options.danger ? 'btn btn-danger' : 'btn btn-primary'}
                onClick={() => finish(true)}
              >
                {options.confirmLabel}
              </button>
            </div>
          </div>
        )}
      </dialog>
    </ConfirmContext.Provider>
  );
}

export function useConfirm(): ConfirmFn {
  const confirm = useContext(ConfirmContext);
  if (!confirm) throw new Error('useConfirm needs ConfirmProvider (root layout)');
  return confirm;
}
