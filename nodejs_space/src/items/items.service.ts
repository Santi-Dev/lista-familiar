import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ItemCategory } from '@prisma/client';

const CATEGORY_ORDER: ItemCategory[] = [
  'FRUTAS_VERDURAS', 'LACTEOS_HUEVOS', 'CARNES_PESCADO', 'PANADERIA',
  'LIMPIEZA', 'BEBIDAS', 'DESPENSA', 'OTROS',
];

@Injectable()
export class ItemsService {
  constructor(private prisma: PrismaService) {}

  private async getUserGroupId(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { familyGroupId: true } });
    if (!user?.familyGroupId) throw new ForbiddenException({ statusCode: 403, message: 'No perteneces a ningún grupo', code: 'NO_FAMILY_GROUP' });
    return user.familyGroupId;
  }

  private async verifyListAccess(userId: string, listId: string) {
    const groupId = await this.getUserGroupId(userId);
    const list = await this.prisma.shoppingList.findUnique({ where: { id: listId } });
    if (!list || list.familyGroupId !== groupId) throw new NotFoundException({ statusCode: 404, message: 'Lista no encontrada', code: 'NOT_FOUND' });
    return { list, groupId };
  }

  private async verifyItemAccess(userId: string, itemId: string) {
    const groupId = await this.getUserGroupId(userId);
    const item = await this.prisma.listItem.findUnique({ where: { id: itemId }, include: { shoppingList: true } });
    if (!item || item.shoppingList.familyGroupId !== groupId) throw new NotFoundException({ statusCode: 404, message: 'Artículo no encontrado', code: 'NOT_FOUND' });
    return { item, groupId };
  }

  async getListItems(userId: string, listId: string) {
    const { list } = await this.verifyListAccess(userId, listId);

    const items = await this.prisma.listItem.findMany({
      where: { shoppingListId: listId },
      include: {
        addedBy: { select: { id: true, name: true } },
        purchasedBy: { select: { id: true, name: true } },
      },
    });

    items.sort((a, b) => {
      const catA = CATEGORY_ORDER.indexOf(a.category);
      const catB = CATEGORY_ORDER.indexOf(b.category);
      if (catA !== catB) return catA - catB;
      if (a.isPurchased !== b.isPurchased) return a.isPurchased ? 1 : -1;
      return a.createdAt.getTime() - b.createdAt.getTime();
    });

    const totalCount = items.length;
    const purchasedCount = items.filter((i) => i.isPurchased).length;

    const listSummary = {
      id: list.id, name: list.name, isArchived: list.isArchived,
      createdBy: null as any, itemCount: totalCount, purchasedCount,
      createdAt: list.createdAt.toISOString(), updatedAt: list.updatedAt.toISOString(),
    };

    return {
      list: listSummary,
      items: items.map((i) => ({
        id: i.id, shoppingListId: i.shoppingListId, name: i.name, quantity: i.quantity,
        category: i.category, isPurchased: i.isPurchased,
        purchasedBy: i.purchasedBy, purchasedAt: i.purchasedAt?.toISOString() ?? null,
        addedBy: i.addedBy, createdAt: i.createdAt.toISOString(), updatedAt: i.updatedAt.toISOString(),
      })),
    };
  }

  async createItem(userId: string, listId: string, data: { name: string; quantity?: string; category: ItemCategory }) {
    await this.verifyListAccess(userId, listId);
    const item = await this.prisma.listItem.create({
      data: {
        shoppingListId: listId,
        name: data.name.trim(),
        quantity: data.quantity?.trim() || null,
        category: data.category,
        addedById: userId,
      },
      include: { addedBy: { select: { id: true, name: true } }, purchasedBy: { select: { id: true, name: true } } },
    });
    await this.prisma.shoppingList.update({ where: { id: listId }, data: { updatedAt: new Date() } });
    return this.toItemDto(item);
  }

  async updateItem(userId: string, itemId: string, data: { name?: string; quantity?: string | null; category?: ItemCategory; isPurchased?: boolean }) {
    const { item } = await this.verifyItemAccess(userId, itemId);

    const updateData: any = {};
    if (data.name !== undefined) updateData.name = data.name.trim();
    if (data.quantity !== undefined) updateData.quantity = data.quantity?.trim() || null;
    if (data.category !== undefined) updateData.category = data.category;
    if (data.isPurchased !== undefined) {
      updateData.isPurchased = data.isPurchased;
      if (data.isPurchased) {
        updateData.purchasedById = userId;
        updateData.purchasedAt = new Date();
      } else {
        updateData.purchasedById = null;
        updateData.purchasedAt = null;
      }
    }

    const updated = await this.prisma.listItem.update({
      where: { id: itemId },
      data: updateData,
      include: { addedBy: { select: { id: true, name: true } }, purchasedBy: { select: { id: true, name: true } } },
    });
    await this.prisma.shoppingList.update({ where: { id: item.shoppingListId }, data: { updatedAt: new Date() } });
    return this.toItemDto(updated);
  }

  async deleteItem(userId: string, itemId: string) {
    const { item } = await this.verifyItemAccess(userId, itemId);
    await this.prisma.listItem.delete({ where: { id: itemId } });
    await this.prisma.shoppingList.update({ where: { id: item.shoppingListId }, data: { updatedAt: new Date() } });
    return { success: true };
  }

  private toItemDto(i: any) {
    return {
      id: i.id, shoppingListId: i.shoppingListId, name: i.name, quantity: i.quantity,
      category: i.category, isPurchased: i.isPurchased,
      purchasedBy: i.purchasedBy, purchasedAt: i.purchasedAt?.toISOString() ?? null,
      addedBy: i.addedBy, createdAt: i.createdAt.toISOString(), updatedAt: i.updatedAt.toISOString(),
    };
  }
}
