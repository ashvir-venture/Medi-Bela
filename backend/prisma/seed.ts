import { PrismaClient, Role } from '@prisma/client';
import argon2 from 'argon2';

const prisma = new PrismaClient();

async function main() {
  const adminPhone = process.env.SEED_ADMIN_PHONE ?? '01810314801';
  const adminPassword = process.env.SEED_ADMIN_PASSWORD ?? '1234Qw!';

  const passwordHash = await argon2.hash(adminPassword);

  const admin = await prisma.user.upsert({
    where: { phone: adminPhone },
    update: {
      passwordHash,
    },
    create: {
      phone: adminPhone,
      name: 'Medi-Bela Admin',
      passwordHash,
      role: Role.ADMIN,
    },
  });

  console.log(`Seeded admin user: ${admin.phone} (id: ${admin.id})`);
  console.log('Default password is set from SEED_ADMIN_PASSWORD env var.');
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });