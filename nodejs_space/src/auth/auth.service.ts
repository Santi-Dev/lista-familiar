import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  async signup(email: string, password: string, name: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (existing) throw new ConflictException({ statusCode: 409, message: 'Este correo ya está registrado', code: 'EMAIL_TAKEN' });
    const hashed = await bcrypt.hash(password, 10);
    const user = await this.prisma.user.create({ data: { email: normalizedEmail, password: hashed, name: name.trim() } });
    const token = this.jwt.sign({ sub: user.id });
    return { token, user: this.toAuthUser(user) };
  }

  async login(email: string, password: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (!user) throw new UnauthorizedException({ statusCode: 401, message: 'Correo o contraseña incorrectos', code: 'INVALID_CREDENTIALS' });
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) throw new UnauthorizedException({ statusCode: 401, message: 'Correo o contraseña incorrectos', code: 'INVALID_CREDENTIALS' });
    const token = this.jwt.sign({ sub: user.id });
    return { token, user: this.toAuthUser(user) };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    return { user: this.toAuthUser(user) };
  }

  private toAuthUser(user: any) {
    return { id: user.id, email: user.email, name: user.name, familyGroupId: user.familyGroupId };
  }
}
