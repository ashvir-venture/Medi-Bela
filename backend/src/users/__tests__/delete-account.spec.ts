import { ForbiddenException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { UsersService } from '../users.service';
import { cloudinaryPublicId } from '../../prescriptions/lib/cloudinary.service';

async function setup(opts: { role?: string; members?: number } = {}) {
  const user = { id: 'u1', phone: '+8801712345678', role: opts.role ?? 'USER', passwordHash: await argon2.hash('Correct123') };
  const calls: string[] = [];
  const tx: any = {
    familyMember: { findUnique: jest.fn(async () => ({ familyId: 'f1' })), count: jest.fn(async () => opts.members ?? 0) },
    familyInvitation: { deleteMany: jest.fn(async () => (calls.push('invitations'), { count: 1 })) },
    user: { delete: jest.fn(async () => (calls.push('user'), user)) },
    family: { delete: jest.fn(async () => (calls.push('family'), {})) },
  };
  const prisma: any = {
    user: { findUnique: jest.fn(async () => user) },
    prescription: { findMany: jest.fn(async () => [{ imageUrl: 'https://res.cloudinary.com/x/image/upload/v1/prescriptions/a1.jpg' }]) },
    $transaction: async (fn: any) => fn(tx),
  };
  const cloudinary = { deleteImageByUrl: jest.fn(async () => undefined) };
  return { service: new UsersService(prisma, cloudinary as any), prisma, tx, calls, cloudinary };
}

describe('deleteAccount', () => {
  it('deletes the user after re-authentication: invitations first (RESTRICT FK), then the user, then images', async () => {
    const s = await setup();
    await s.service.deleteAccount('u1', 'Correct123');
    expect(s.calls).toEqual(['invitations', 'user', 'family']);
    expect(s.tx.familyInvitation.deleteMany.mock.calls[0][0].where.OR).toEqual([{ invitedById: 'u1' }, { invitedPhone: '+8801712345678' }]);
    expect(s.tx.user.delete).toHaveBeenCalledWith({ where: { id: 'u1' } });
    expect(s.cloudinary.deleteImageByUrl).toHaveBeenCalledWith('https://res.cloudinary.com/x/image/upload/v1/prescriptions/a1.jpg');
  });

  it('keeps a family that still has other members', async () => {
    const s = await setup({ members: 2 });
    await s.service.deleteAccount('u1', 'Correct123');
    expect(s.calls).toEqual(['invitations', 'user']);
  });

  it('wrong password: 403 (never 401: the app would log the user out), nothing deleted; repeated failures are throttled (429)', async () => {
    const s = await setup();
    for (let i = 0; i < 8; i++) await expect(s.service.deleteAccount('u1', 'nope')).rejects.toThrow(ForbiddenException);
    await expect(s.service.deleteAccount('u1', 'Correct123')).rejects.toMatchObject({ status: 429 });
    expect(s.tx.user.delete).not.toHaveBeenCalled();
    expect(s.cloudinary.deleteImageByUrl).not.toHaveBeenCalled();
  });

  it('staff accounts cannot be deleted from the app', async () => {
    const s = await setup({ role: 'ADMIN' });
    await expect(s.service.deleteAccount('u1', 'Correct123')).rejects.toThrow(ForbiddenException);
    expect(s.tx.user.delete).not.toHaveBeenCalled();
  });
});

describe('cloudinaryPublicId', () => {
  it('derives the storage id from a delivery URL, and ignores foreign URLs', () => {
    expect(cloudinaryPublicId('https://res.cloudinary.com/demo/image/upload/v1699/prescriptions/abc123.jpg')).toBe('prescriptions/abc123');
    expect(cloudinaryPublicId('https://res.cloudinary.com/demo/image/upload/prescriptions/abc.png')).toBe('prescriptions/abc');
    expect(cloudinaryPublicId('https://evil.example.com/image/upload/v1/prescriptions/abc.jpg')).toBeNull();
  });
});
