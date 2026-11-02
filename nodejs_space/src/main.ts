import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // La app iOS no usa CORS; solo se permite el origen configurado (si existe).
  const origin = process.env.APP_ORIGIN;
  app.enableCors(origin ? { origin } : { origin: false });

  // Swagger solo fuera de producción.
  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('Lista Familiar API')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('api-docs', app, SwaggerModule.createDocument(app, config));
  }

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
