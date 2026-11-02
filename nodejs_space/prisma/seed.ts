import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const seedPassword = process.env.SEED_PASSWORD;
  if (!seedPassword) throw new Error('Define SEED_PASSWORD para ejecutar el seed');
  const hashedPassword = await bcrypt.hash(seedPassword, 10);
  await prisma.user.upsert({
    where: { email: 'abacus-a94d7d91@example.com' },
    update: {},
    create: {
      email: 'abacus-a94d7d91@example.com',
      password: hashedPassword,
      name: 'Admin Test',
    },
  });
  console.log('Seed completed');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
