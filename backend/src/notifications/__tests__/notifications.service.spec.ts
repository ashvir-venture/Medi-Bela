import { NotificationsService, MAX_PUSH_ATTEMPTS } from '../notifications.service';

/** Minimal in-memory notification table + fakes for push/devices, exercising the real dispatch code. */
function setup(opts: { enabled?: boolean; tokens?: Array<{ id: string; token: string }>; user?: any; sendResults?: any[] | Error } = {}) {
  const rows: any[] = [
    { id: 'n1', userId: 'u1', type: 'PRESCRIPTION_UPDATE', title: 't', body: 'b', data: { prescriptionId: 'p1' }, pushStatus: 'PENDING', pushAttempts: 0, createdAt: new Date() },
  ];
  const prisma: any = {
    notification: {
      // copies, like a real DB: a row read before another worker's claim must still show the old attempt count
      findMany: jest.fn(async ({ where }: any) => rows.filter((r) => (!where.id || where.id.in.includes(r.id)) && r.pushStatus === where.pushStatus).map((r) => ({ ...r }))),
      updateMany: jest.fn(async ({ where, data }: any) => {
        const orOk = (r: any) => !where.OR || where.OR.some((c: any) => (c.pushAttempts?.gte !== undefined && r.pushAttempts >= c.pushAttempts.gte) || (c.createdAt?.lte && r.createdAt <= c.createdAt.lte));
        const hit = rows.filter((r) => orOk(r) && (where.id?.in ? where.id.in.includes(r.id) : where.id ? r.id === where.id : true) && (where.pushStatus ? r.pushStatus === where.pushStatus : true) && (where.pushAttempts !== undefined && typeof where.pushAttempts === 'number' ? r.pushAttempts === where.pushAttempts : true));
        hit.forEach((r) => {
          for (const [k, v] of Object.entries(data) as [string, any][]) r[k] = v && typeof v === 'object' && 'increment' in v ? r[k] + v.increment : v;
        });
        return { count: hit.length };
      }),
      update: jest.fn(async ({ where, data }: any) => Object.assign(rows.find((r) => r.id === where.id), data)),
    },
    user: { findMany: jest.fn(async () => [opts.user ?? { id: 'u1', notificationsEnabled: true, accountStatus: 'ACTIVE' }]) },
  };
  const push = {
    isEnabled: jest.fn(() => opts.enabled ?? true),
    send: jest.fn(async (tokens: string[], _message?: any) => {
      if (opts.sendResults instanceof Error) throw opts.sendResults;
      return opts.sendResults ?? tokens.map((t) => ({ token: t, ok: true, permanentTokenFailure: false }));
    }),
  };
  const devices = {
    tokensForUsers: jest.fn(async () => new Map([['u1', opts.tokens ?? [{ id: 'd1', token: 'tok-aaaaaaaaaaaaaaaaaaaa' }]]])),
    removeByIds: jest.fn(async () => undefined),
  };
  const service = new NotificationsService(prisma, push as any, devices as any);
  return { service, rows, push, devices };
}

describe('push dispatch', () => {
  it('delivers: SENT, routing data + notificationId/type included, no health text added', async () => {
    const { service, rows, push } = setup();
    await service.dispatch(['n1']);
    expect(rows[0]).toMatchObject({ pushStatus: 'SENT', pushAttempts: 1 });
    expect(push.send.mock.calls[0][1]).toMatchObject({ title: 't', collapseKey: 'n1', data: { prescriptionId: 'p1', notificationId: 'n1', type: 'PRESCRIPTION_UPDATE' } });
  });

  it('never sends a notification twice (already SENT, or two workers racing)', async () => {
    const { service, push } = setup();
    await Promise.all([service.dispatch(['n1']), service.dispatch(['n1'])]);
    await service.dispatch(['n1']);
    expect(push.send).toHaveBeenCalledTimes(1);
  });

  it('FCM not configured: SKIPPED, nothing sent (the in-app inbox still has it)', async () => {
    const { service, rows, push } = setup({ enabled: false });
    await service.dispatch(['n1']);
    expect(rows[0].pushStatus).toBe('SKIPPED');
    expect(push.send).not.toHaveBeenCalled();
  });

  it('user turned notifications off / inactive account: SKIPPED; no registered device: SKIPPED', async () => {
    const off = setup({ user: { id: 'u1', notificationsEnabled: false, accountStatus: 'ACTIVE' } });
    await off.service.dispatch(['n1']);
    expect(off.rows[0].pushStatus).toBe('SKIPPED');
    expect(off.push.send).not.toHaveBeenCalled();
    const none = setup({ tokens: [] });
    await none.service.dispatch(['n1']);
    expect(none.rows[0].pushStatus).toBe('SKIPPED');
  });

  it('temporary FCM failure: stays PENDING for the retry job; FAILED after the last attempt', async () => {
    const { service, rows } = setup({ sendResults: [{ token: 'tok-aaaaaaaaaaaaaaaaaaaa', ok: false, permanentTokenFailure: false, errorCode: 'messaging/internal-error' }] });
    await service.dispatch(['n1']);
    expect(rows[0]).toMatchObject({ pushStatus: 'PENDING', pushAttempts: 1 });
    for (let i = 1; i < MAX_PUSH_ATTEMPTS; i++) await service.dispatchPending();
    expect(rows[0]).toMatchObject({ pushStatus: 'FAILED', pushAttempts: MAX_PUSH_ATTEMPTS });
  });

  it('a thrown send error never escapes (business action unaffected) and is retried', async () => {
    const { service, rows } = setup({ sendResults: new Error('network down') });
    await expect(service.dispatch(['n1'])).resolves.toBeUndefined();
    expect(rows[0].pushStatus).toBe('PENDING');
  });

  it('dead tokens (uninstalled app) are deleted; if all were dead the notification is SKIPPED', async () => {
    const { service, rows, devices } = setup({ sendResults: [{ token: 'tok-aaaaaaaaaaaaaaaaaaaa', ok: false, permanentTokenFailure: true, errorCode: 'messaging/registration-token-not-registered' }] });
    await service.dispatch(['n1']);
    expect(devices.removeByIds).toHaveBeenCalledWith(['d1']);
    expect(rows[0].pushStatus).toBe('SKIPPED');
  });
});
