import { Controller, Post, Get, Body, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiProperty } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class AuthUserDto {
  @ApiProperty() id: string;
  @ApiProperty() email: string;
  @ApiProperty() name: string;
  @ApiProperty({ nullable: true, type: String }) familyGroupId: string | null;
}

export class AuthResponseDto {
  @ApiProperty() token: string;
  @ApiProperty({ type: AuthUserDto }) user: AuthUserDto;
}

export class MeResponseDto {
  @ApiProperty({ type: AuthUserDto }) user: AuthUserDto;
}

export class SignupDto {
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty() @IsString() @MinLength(8) password: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(60) name: string;
}

export class LoginDto {
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty() @IsString() password: string;
}

@ApiTags('Auth')
@Controller('api')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('signup')
  async signup(@Body() dto: SignupDto): Promise<AuthResponseDto> {
    return this.authService.signup(dto.email, dto.password, dto.name);
  }

  @Post('auth/login')
  async login(@Body() dto: LoginDto): Promise<AuthResponseDto> {
    return this.authService.login(dto.email, dto.password);
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Get('auth/me')
  async me(@Request() req: any): Promise<MeResponseDto> {
    return this.authService.me(req.user.userId);
  }
}
