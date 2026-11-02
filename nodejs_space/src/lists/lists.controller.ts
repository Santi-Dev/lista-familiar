import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, ParseUUIDPipe, Request } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ListsService } from './lists.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { IsString, IsOptional, IsBoolean, MinLength, MaxLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { UserPublicDto } from '../family-groups/family-groups.controller';

export class ShoppingListSummaryDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() isArchived: boolean;
  @ApiProperty({ type: UserPublicDto, nullable: true }) createdBy: UserPublicDto | null;
  @ApiProperty() itemCount: number;
  @ApiProperty() purchasedCount: number;
  @ApiProperty() createdAt: string;
  @ApiProperty() updatedAt: string;
}

export class ListsResponseDto {
  @ApiProperty({ type: [ShoppingListSummaryDto] }) items: ShoppingListSummaryDto[];
}

export class CreateListDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(80) name: string;
}

export class UpdateListDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(80) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isArchived?: boolean;
}

export class SuccessResponseDto {
  @ApiProperty() success: boolean;
}

@ApiTags('Lists')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/lists')
export class ListsController {
  constructor(private service: ListsService) {}

  @Get()
  async getLists(@Request() req: any, @Query('archived') archived?: string): Promise<ListsResponseDto> {
    const isArchived = archived === 'true';
    return this.service.getLists(req.user.userId, isArchived);
  }

  @Post()
  async create(@Request() req: any, @Body() dto: CreateListDto): Promise<ShoppingListSummaryDto> {
    return this.service.createList(req.user.userId, dto.name);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateListDto): Promise<ShoppingListSummaryDto> {
    return this.service.updateList(req.user.userId, id, dto);
  }

  @Delete(':id')
  async delete(@Request() req: any, @Param('id', ParseUUIDPipe) id: string): Promise<SuccessResponseDto> {
    return this.service.deleteList(req.user.userId, id);
  }
}
