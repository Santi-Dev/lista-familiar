import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const hashedPassword = await bcrypt.hash('v81UPI*sCe', 10);
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
