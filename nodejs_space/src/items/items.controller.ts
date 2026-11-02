import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ItemsService } from './items.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { IsString, IsOptional, IsBoolean, IsEnum, MinLength, MaxLength } from 'class-validator';
import { ItemCategory } from '@prisma/client';
import { UserPublicDto, SuccessDto } from '../family-groups/family-groups.controller';
import { ShoppingListSummaryDto } from '../lists/lists.controller';

export class ListItemDto {
  @ApiProperty() id: string;
  @ApiProperty() shoppingListId: string;
  @ApiProperty() name: string;
  @ApiProperty({ nullable: true, type: String }) quantity: string | null;
  @ApiProperty({ enum: ItemCategory }) category: ItemCategory;
  @ApiProperty() isPurchased: boolean;
  @ApiProperty({ type: UserPublicDto, nullable: true }) purchasedBy: UserPublicDto | null;
  @ApiProperty({ nullable: true, type: String }) purchasedAt: string | null;
  @ApiProperty({ type: UserPublicDto, nullable: true }) addedBy: UserPublicDto | null;
  @ApiProperty() createdAt: string;
  @ApiProperty() updatedAt: string;
}

export class ListItemsResponseDto {
  @ApiProperty({ type: ShoppingListSummaryDto }) list: ShoppingListSummaryDto;
  @ApiProperty({ type: [ListItemDto] }) items: ListItemDto[];
}

export class CreateItemDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(80) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(30) quantity?: string;
  @ApiProperty({ enum: ItemCategory }) @IsEnum(ItemCategory) category: ItemCategory;
}

export class UpdateItemDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(80) name?: string;
  @ApiPropertyOptional({ nullable: true, type: String }) @IsOptional() @IsString() quantity?: string | null;
  @ApiPropertyOptional({ enum: ItemCategory }) @IsOptional() @IsEnum(ItemCategory) category?: ItemCategory;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isPurchased?: boolean;
}

@ApiTags('Items')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api')
export class ItemsController {
  constructor(private service: ItemsService) {}

  @Get('lists/:id/items')
  async getListItems(@Request() req: any, @Param('id') id: string): Promise<ListItemsResponseDto> {
    return this.service.getListItems(req.user.userId, id);
  }

  @Post('lists/:id/items')
  async createItem(@Request() req: any, @Param('id') id: string, @Body() dto: CreateItemDto): Promise<ListItemDto> {
    return this.service.createItem(req.user.userId, id, dto);
  }

  @Patch('items/:id')
  async updateItem(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateItemDto): Promise<ListItemDto> {
    return this.service.updateItem(req.user.userId, id, dto);
  }

  @Delete('items/:id')
  async deleteItem(@Request() req: any, @Param('id') id: string): Promise<SuccessDto> {
    return this.service.deleteItem(req.user.userId, id);
  }
}
