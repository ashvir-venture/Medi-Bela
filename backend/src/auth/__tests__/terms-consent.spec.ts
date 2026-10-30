import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RegisterDto } from '../dto/register.dto';
import { AuthService } from '../auth.service';

const base = {
  phone: '01712345678',
  name: 'Rahima Begum',
  password: 'pass1234',
  dateOfBirth: '1960-05-20',
  genderId: 1,
  divisionId: 1,
  districtId: 1,
  upazilaId: 1,
};

async function errorsFor(body: Record<string, unknown>) {
  const errors = await validate(plainToInstance(RegisterDto, body), { whitelist: true, forbidNonWhitelisted: true });
  return errors.map((e) => e.property);
}

describe('sign-up consent (Privacy & terms)', () => {
  it('sign-up needs the box ticked: missing or false is refused', async () => {
    expect(await errorsFor(base)).toContain('acceptTerms');
    expect(await errorsFor({ ...base, acceptTerms: false })).toContain('acceptTerms');
    expect(await errorsFor({ ...base, acceptTerms: 'yes' })).toContain('acceptTerms');
    expect(await errorsFor({ ...base, acceptTerms: true })).toEqual([]);
  });

  it('the account records when the user agreed', async () => {
    let created: any;
    const prisma: any = {
      gender: { findUnique: jest.fn(async () => ({ id: 1 })) },
      upazila: { findUnique: jest.fn(async () => ({ id: 1, districtId: 1, district: { divisionId: 1 } })) },
      user: {
        create: jest.fn(async ({ data }: any) => (created = { id: 'u1', role: 'USER', ...data })),
      },
    };
    const jwt = { signAsync: jest.fn(async () => 'token') };
    const config = { getOrThrow: () => 'secret', get: () => undefined };
    const service = new AuthService(prisma, jwt as any, config as any, {} as any, { record: jest.fn() } as any);
    const before = Date.now();
    await service.register({ ...base, phone: '+8801712345678', acceptTerms: true } as any);
    expect(created.termsAcceptedAt).toBeInstanceOf(Date);
    expect(created.termsAcceptedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(created).not.toHaveProperty('acceptTerms');
  });
});
