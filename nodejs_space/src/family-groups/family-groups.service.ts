import { Injectable, ConflictException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function generateCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
  return code;
}

@Injectable()
export class FamilyGroupsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, name: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user?.familyGroupId) throw new ConflictException({ statusCode: 409, message: 'Ya perteneces a un grupo', code: 'ALREADY_IN_GROUP' });

    let inviteCode = generateCode();
    let attempts = 0;
    while (attempts < 10) {
      const exists = await this.prisma.familyGroup.findUnique({ where: { inviteCode } });
      if (!exists) break;
      inviteCode = generateCode();
      attempts++;
    }

    const group = await this.prisma.$transaction(async (tx) => {
      const g = await tx.familyGroup.create({ data: { name: name.trim(), inviteCode, createdById: userId } });
      await tx.user.update({ where: { id: userId }, data: { familyGroupId: g.id } });
      return g;
    });

    return this.getGroupDto(group.id);
  }

  async join(userId: string, code: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user?.familyGroupId) throw new ConflictException({ statusCode: 409, message: 'Ya perteneces a un grupo', code: 'ALREADY_IN_GROUP' });

    const normalizedCode = code.trim().toUpperCase();
    const group = await this.prisma.familyGroup.findUnique({ where: { inviteCode: normalizedCode } });
    if (!group) throw new NotFoundException({ statusCode: 404, message: 'Código no válido', code: 'INVALID_CODE' });

    await this.prisma.user.update({ where: { id: userId }, data: { familyGroupId: group.id } });
    return this.getGroupDto(group.id);
  }

  async getMyGroup(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.familyGroupId) throw new ForbiddenException({ statusCode: 403, message: 'No perteneces a ningún grupo', code: 'NO_FAMILY_GROUP' });
    return this.getGroupDto(user.familyGroupId);
  }

  async leave(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.familyGroupId) throw new ForbiddenException({ statusCode: 403, message: 'No perteneces a ningún grupo', code: 'NO_FAMILY_GROUP' });

    const groupId = user.familyGroupId;
    await this.prisma.user.update({ where: { id: userId }, data: { familyGroupId: null } });

    const remaining = await this.prisma.user.count({ where: { familyGroupId: groupId } });
    if (remaining === 0) {
      await this.prisma.familyGroup.delete({ where: { id: groupId } });
    }

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
