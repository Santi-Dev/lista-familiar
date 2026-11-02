import { Module } from '@nestjs/common';
import { FamilyGroupsService } from './family-groups.service';
import { FamilyGroupsController } from './family-groups.controller';

@Module({
  providers: [FamilyGroupsService],
  controllers: [FamilyGroupsController],
})
export class FamilyGroupsModule {}
