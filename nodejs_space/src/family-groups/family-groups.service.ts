import { Injectable, ConflictException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

import { randomInt } from 'crypto';
import { Prisma } from '@prisma/client';

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function generateCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) code += CODE_CHARS[randomInt(CODE_CHARS.length)];
  return code;
}

const ALREADY_IN_GROUP = { statusCode: 409, message: 'Ya perteneces a un grupo', code: 'ALREADY_IN_GROUP' };

@Injectable()
export class FamilyGroupsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, name: string) {
    // El código se genera dentro de la transacción y se reintenta si choca con el
    // índice único (P2002), en vez de asumir que el último candidato es libre.
    for (let attempt = 0; attempt < 10; attempt++) {
      try {
        const group = await this.prisma.$transaction(async (tx) => {
          const claimed = await tx.user.updateMany({
            where: { id: userId, familyGroupId: null },
            data: {},
          });
          if (claimed.count === 0) throw new ConflictException(ALREADY_IN_GROUP);
          const g = await tx.familyGroup.create({
            data: { name: name.trim(), inviteCode: generateCode(), createdById: userId },
          });
          await tx.user.update({ where: { id: userId }, data: { familyGroupId: g.id } });
          return g;
        });
        return this.getGroupDto(group.id);
      } catch (e) {
        if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') continue;
        throw e;
      }
    }
    throw new ConflictException({ statusCode: 409, message: 'No se pudo generar un código, inténtalo de nuevo', code: 'CODE_GENERATION_FAILED' });
  }

  async join(userId: string, code: string) {
    const normalizedCode = code.trim().toUpperCase();
    const group = await this.prisma.familyGroup.findUnique({ where: { inviteCode: normalizedCode } });
    if (!group) throw new NotFoundException({ statusCode: 404, message: 'Código no válido', code: 'INVALID_CODE' });

    // Atómico: solo se une si todavía no pertenece a ningún grupo.
    const joined = await this.prisma.user.updateMany({
      where: { id: userId, familyGroupId: null },
      data: { familyGroupId: group.id },
    });
    if (joined.count === 0) throw new ConflictException(ALREADY_IN_GROUP);
    return this.getGroupDto(group.id);
  }

  async getMyGroup(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.familyGroupId) throw new ForbiddenException({ statusCode: 403, message: 'No perteneces a ningún grupo', code: 'NO_FAMILY_GROUP' });
    return this.getGroupDto(user.familyGroupId);
  }

  async leave(userId: string) {
    await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user?.familyGroupId) throw new ForbiddenException({ statusCode: 403, message: 'No perteneces a ningún grupo', code: 'NO_FAMILY_GROUP' });
      const groupId = user.familyGroupId;
      await tx.user.update({ where: { id: userId }, data: { familyGroupId: null } });
      const remaining = await tx.user.count({ where: { familyGroupId: groupId } });
      if (remaining === 0) await tx.familyGroup.delete({ where: { id: groupId } });
    });
    return { success: true };
  }

  private async getGroupDto(groupId: string) {
    const group = await this.prisma.familyGroup.findUnique({
      where: { id: groupId },
      include: { members: { select: { id: true, name: true }, orderBy: { name: 'asc' } } },
    });
    return {
      id: group!.id,
      name: group!.name,
      inviteCode: group!.inviteCode,
      createdById: group!.createdById,
      members: group!.members,
      createdAt: group!.createdAt.toISOString(),
    };
  }
}
