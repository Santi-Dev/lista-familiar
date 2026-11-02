import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as fs from 'fs';
import * as path from 'path';
import { AppModule } from './app.module';

async function main() {
  const app = await NestFactory.create(AppModule, { logger: false });
  const config = new DocumentBuilder()
    .setTitle('Api')
    .setVersion('0.1.0')
    .build();
  const document = SwaggerModule.createDocument(app, config);
  const out = path.resolve(process.cwd(), 'swagger.json');
  fs.writeFileSync(out, JSON.stringify(document, null, 2));
  console.log('[dump-swagger] wrote', out);
  await app.close();
}

main().catch((err) => {
  console.error('[dump-swagger] failed:', err);
  process.exit(1);
});