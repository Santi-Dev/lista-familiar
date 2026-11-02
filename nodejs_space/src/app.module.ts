import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { FamilyGroupsModule } from './family-groups/family-groups.module';
import { ListsModule } from './lists/lists.module';
import { ItemsModule } from './items/items.module';

@Module({
  imports: [PrismaModule, AuthModule, FamilyGroupsModule, ListsModule, ItemsModule],
})
export class AppModule {}
