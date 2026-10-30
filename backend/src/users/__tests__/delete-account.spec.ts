import { ForbiddenException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { UsersService } from '../users.service';
import { cloudinaryPublicId } from '../../prescriptions/lib/cloudinary.service';
import { DELETED_USER_NAME } from '../lib/deleted-user';

async function setup(opts: { role?: string } = {}) {
  const user = {
    id: 'u1',
    phone: '+8801712345678',
    role: opts.role ?? 'USER',
    passwordHash: await argon2.hash('Correct123'),
    dateOfBirth: new Date('1958-04-12T00:00:00Z'),
    birthYear: null,
  };
  const calls: string[] = [];
  const log = (name: string) => jest.fn(async (..._args: any[]) => (calls.push(name), { count: 1 }));
  const tx: any = {
    familyInvitation: { deleteMany: log('invitations') },
    medicineDose: { deleteMany: log('doses') },
    medicineRoutine: { updateMany: log('routines') },
    prescription: { deleteMany: log('prescriptions.delete'), updateMany: log('prescriptions.photo') },
    healthRecord: { deleteMany: log('healthRecords') },
    healthReminder: { deleteMany: log('healthReminders') },
    healthSuggestion: { deleteMany: log('healthSuggestions') },
    assistantConversation: { deleteMany: log('conversations') },
    notification: { deleteMany: log('notifications') },
    passwordResetCode: { deleteMany: log('resetCode') },
    user: { update: jest.fn(async () => (calls.push('user'), user)) },
  };
  const prisma: any = {
    user: { findUnique: jest.fn(async () => user) },
    prescription: {
      findMany: jest.fn(async () => [{ imageUrl: 'https://res.cloudinary.com/x/image/upload/v1/prescriptions/a1.jpg' }]),
    },
    $transaction: async (fn: any) => fn(tx),
  };
  const cloudinary = { deleteImageByUrl: jest.fn(async () => undefined) };
  const audit = { record: jest.fn(async (..._args: any[]) => undefined) };
  const notifications = { endSessions: jest.fn(async () => calls.push('endSessions')) };
  const departure = { familyId: 'f1', familyRemoved: false, newCaregiverId: 'u2', removedUserId: null };
  const family = {
    depart: jest.fn(async () => (calls.push('depart'), departure)),
    notifyAfterCommit: jest.fn(async () => undefined),
  };
  const service = new UsersService(prisma, cloudinary as any, audit as any, notifications as any, family as any);
  return { service, prisma, tx, calls, cloudinary, audit, notifications, family, departure };
}

describe('deleteAccount (de-identify)', () => {
  it('erases personal data, keeps the row, removes waiting prescriptions and every photo', async () => {
    const s = await setup();
    await s.service.deleteAccount('u1', 'Correct123');

    const data = s.tx.user.update.mock.calls[0][0].data;
    expect(data).toMatchObject({
      phone: null,
      name: DELETED_USER_NAME,
      address: null,
      dateOfBirth: null,
      birthYear: 1958,
      upazilaId: null,
      accountStatus: 'DELETED',
      notificationsEnabled: false,
      medicineRemindersEnabled: false,
      noticesEnabled: false,
    });
    expect(data.deletedAt).toBeInstanceOf(Date);
    expect(data.passwordChangedAt).toBeInstanceOf(Date);
    // The old password no longer works.
    expect(await argon2.verify(data.passwordHash, 'Correct123')).toBe(false);
    // Gender, division and district are not touched (kept for analytics).
    expect(data).not.toHaveProperty('genderId');
    expect(data).not.toHaveProperty('divisionId');
    expect(data).not.toHaveProperty('districtId');

    expect(s.tx.prescription.deleteMany.mock.calls[0][0].where.status.in).toEqual(['PENDING', 'AWAITING_CONFIRMATION']);
    expect(s.tx.prescription.updateMany).toHaveBeenCalledWith({ where: { userId: 'u1' }, data: { imageUrl: null } });
    for (const t of ['healthRecord', 'healthReminder', 'healthSuggestion', 'assistantConversation', 'notification', 'passwordResetCode']) {
      expect(s.tx[t].deleteMany).toHaveBeenCalledWith({ where: { userId: 'u1' } });
    }
    expect(s.tx.medicineRoutine.updateMany).toHaveBeenCalledWith({ where: { userId: 'u1', active: true }, data: { active: false } });
    expect(s.tx.familyInvitation.deleteMany.mock.calls.at(-1)[0].where.OR).toEqual([
      { invitedById: 'u1' },
      { invitedPhone: '+8801712345678' },
    ]);
    expect(s.cloudinary.deleteImageByUrl).toHaveBeenCalledWith('https://res.cloudinary.com/x/image/upload/v1/prescriptions/a1.jpg');
  });

  it('leaves the family first (handover inside the transaction), signs devices out and pushes after commit', async () => {
    const s = await setup();
    await s.service.deleteAccount('u1', 'Correct123');
    expect(s.family.depart).toHaveBeenCalledWith(s.tx, 'u1', 'LEFT', 'u1');
    expect(s.calls[0]).toBe('depart');
    expect(s.calls.indexOf('endSessions')).toBeGreaterThan(s.calls.indexOf('user'));
    expect(s.family.notifyAfterCommit).toHaveBeenCalledWith(s.departure);
  });

  it('audits user.delete with no personal data', async () => {
    const s = await setup();
    await s.service.deleteAccount('u1', 'Correct123');
    const entry = (s.audit.record.mock.calls as any[]).find((c: any) => c[0].action === 'user.delete')[0];
    expect(entry).toEqual({ actorId: 'u1', subjectUserId: 'u1', action: 'user.delete', entityType: 'user', entityId: 'u1' });
  });

  it('wrong password: 403 (never 401: the app would log the user out), nothing changed; repeated failures are throttled (429)', async () => {
    const s = await setup();
    for (let i = 0; i < 8; i++) await expect(s.service.deleteAccount('u1', 'nope')).rejects.toThrow(ForbiddenException);
    await expect(s.service.deleteAccount('u1', 'Correct123')).rejects.toMatchObject({ status: 429 });
    expect(s.tx.user.update).not.toHaveBeenCalled();
    expect(s.cloudinary.deleteImageByUrl).not.toHaveBeenCalled();
  });

  it('staff accounts cannot be deleted from the app', async () => {
    const s = await setup({ role: 'ADMIN' });
    await expect(s.service.deleteAccount('u1', 'Correct123')).rejects.toThrow(ForbiddenException);
    expect(s.tx.user.update).not.toHaveBeenCalled();
  });
});

describe('deactivate', () => {
  it('pauses the account: status, sessions ended, future doses removed and generation reset, audited', async () => {
    const s = await setup();
    await s.service.deactivate('u1', 'Correct123');
    const data = s.tx.user.update.mock.calls[0][0].data;
    expect(data.accountStatus).toBe('DEACTIVATED');
    expect(data.deactivatedAt).toBeInstanceOf(Date);
    expect(data.passwordChangedAt).toBeInstanceOf(Date);
    expect(s.tx.medicineDose.deleteMany.mock.calls[0][0].where).toMatchObject({ userId: 'u1', status: 'PENDING' });
    expect(s.tx.medicineRoutine.updateMany.mock.calls[0][0].data.generatedUntil).toBeInstanceOf(Date);
    expect((s.audit.record.mock.calls as any[])[0][0].action).toBe('user.deactivate');
    expect(s.notifications.endSessions).toHaveBeenCalledWith('u1');
    // Nothing is erased.
    expect(s.tx.healthRecord.deleteMany).not.toHaveBeenCalled();
    expect(s.family.depart).not.toHaveBeenCalled();
  });

  it('wrong password: 403 and nothing changes', async () => {
    const s = await setup();
    await expect(s.service.deactivate('u1', 'nope')).rejects.toThrow(ForbiddenException);
    expect(s.tx.user.update).not.toHaveBeenCalled();
    expect(s.notifications.endSessions).not.toHaveBeenCalled();
  });
});

describe('cloudinaryPublicId', () => {
  it('derives the storage id from a delivery URL, and ignores foreign URLs', () => {
    expect(cloudinaryPublicId('https://res.cloudinary.com/demo/image/upload/v1699/prescriptions/abc123.jpg')).toBe('prescriptions/abc123');
    expect(cloudinaryPublicId('https://res.cloudinary.com/demo/image/upload/prescriptions/abc.png')).toBe('prescriptions/abc');
    expect(cloudinaryPublicId('https://evil.example.com/image/upload/v1/prescriptions/abc.jpg')).toBeNull();
  });
});
