import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ListsService {
  constructor(private prisma: PrismaService) {}

  private async getUserGroupId(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { familyGroupId: true } });
    if (!user?.familyGroupId) throw new ForbiddenException({ statusCode: 403, message: 'No perteneces a ningún grupo', code: 'NO_FAMILY_GROUP' });
    return user.familyGroupId;
  }

  async getLists(userId: string, archived: boolean) {
    const groupId = await this.getUserGroupId(userId);
    const lists = await this.prisma.shoppingList.findMany({
      where: { familyGroupId: groupId, isArchived: archived },
      include: {
        createdBy: { select: { id: true, name: true } },
        _count: { select: { items: true } },
      },
      orderBy: { updatedAt: 'desc' },
    });

    const purchasedCounts = await Promise.all(
      lists.map((l) => this.prisma.listItem.count({ where: { shoppingListId: l.id, isPurchased: true } }))
    );

    return {
      items: lists.map((l, i) => ({
        id: l.id,
        name: l.name,
        isArchived: l.isArchived,
        createdBy: l.createdBy,
        itemCount: l._count.items,
        purchasedCount: purchasedCounts[i],
        createdAt: l.createdAt.toISOString(),
        updatedAt: l.updatedAt.toISOString(),
      })),
    };
  }

  async createList(userId: string, name: string) {
    const groupId = await this.getUserGroupId(userId);
    const list = await this.prisma.shoppingList.create({
      data: { name: name.trim(), familyGroupId: groupId, createdById: userId },
      include: { createdBy: { select: { id: true, name: true } }, _count: { select: { items: true } } },
    });
    return {
      id: list.id, name: list.name, isArchived: list.isArchived, createdBy: list.createdBy,
      itemCount: list._count.items, purchasedCount: 0,
      createdAt: list.createdAt.toISOString(), updatedAt: list.updatedAt.toISOString(),
    };
  }

  async updateList(userId: string, listId: string, data: { name?: string; isArchived?: boolean }) {
    const groupId = await this.getUserGroupId(userId);
    const list = await this.prisma.shoppingList.findUnique({ where: { id: listId } });
    if (!list || list.familyGroupId !== groupId) throw new NotFoundException({ statusCode: 404, message: 'Lista no encontrada', code: 'NOT_FOUND' });

    const updated = await this.prisma.shoppingList.update({
      where: { id: listId },
      data: { name: data.name?.trim(), isArchived: data.isArchived },
      include: { createdBy: { select: { id: true, name: true } }, _count: { select: { items: true } } },
    });
    const purchasedCount = await this.prisma.listItem.count({ where: { shoppingListId: listId, isPurchased: true } });
    return {
      id: updated.id, name: updated.name, isArchived: updated.isArchived, createdBy: updated.createdBy,
      itemCount: updated._count.items, purchasedCount,
      createdAt: updated.createdAt.toISOString(), updatedAt: updated.updatedAt.toISOString(),
    };
  }

  async deleteList(userId: string, listId: string) {
    const groupId = await this.getUserGroupId(userId);
    const list = await this.prisma.shoppingList.findUnique({ where: { id: listId } });
    if (!list || list.familyGroupId !== groupId) throw new NotFoundException({ statusCode: 404, message: 'Lista no encontrada', code: 'NOT_FOUND' });
    await this.prisma.shoppingList.delete({ where: { id: listId } });
    return { success: true };
  }
}
