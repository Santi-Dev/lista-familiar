import { Controller, Post, Get, Body, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiProperty } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { FamilyGroupsService } from './family-groups.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { IsString, MinLength, MaxLength, Length } from 'class-validator';

export class UserPublicDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
}

export class FamilyGroupDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() inviteCode: string;
  @ApiProperty({ nullable: true, type: String }) createdById: string | null;
  @ApiProperty({ type: [UserPublicDto] }) members: UserPublicDto[];
  @ApiProperty() createdAt: string;
}

export class CreateGroupDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(60) name: string;
}

export class JoinGroupDto {
  @ApiProperty() @IsString() @Length(6, 6) inviteCode: string;
}

export class SuccessDto {
  @ApiProperty() success: boolean;
}

@ApiTags('FamilyGroups')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, ThrottlerGuard)
@Controller('api/family-groups')
export class FamilyGroupsController {
  constructor(private service: FamilyGroupsService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateGroupDto): Promise<FamilyGroupDto> {
    return this.service.create(req.user.userId, dto.name);
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('join')
  async join(@Request() req: any, @Body() dto: JoinGroupDto): Promise<FamilyGroupDto> {
    return this.service.join(req.user.userId, dto.inviteCode);
  }

  @Get('me')
  async me(@Request() req: any): Promise<FamilyGroupDto> {
    return this.service.getMyGroup(req.user.userId);
  }

  @Post('leave')
  async leave(@Request() req: any): Promise<SuccessDto> {
    return this.service.leave(req.user.userId);
  }
}
