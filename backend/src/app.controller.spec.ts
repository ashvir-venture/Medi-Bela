import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaService } from './prisma/prisma.service';

describe('AppController', () => {
  let appController: AppController;
  const prisma = { $queryRaw: jest.fn() };

  beforeEach(async () => {
    prisma.$queryRaw.mockReset();
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('root', () => {
    it('reports service health and touches the database', async () => {
      prisma.$queryRaw.mockResolvedValue([{ '?column?': 1 }]);
      await expect(appController.getHealth()).resolves.toMatchObject({
        status: 'ok',
        db: 'ok',
        service: 'medi-bela backend',
      });
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
    });

    it('still answers ok when the database is down', async () => {
      prisma.$queryRaw.mockRejectedValue(new Error('connection refused'));
      await expect(appController.getHealth()).resolves.toMatchObject({ status: 'ok', db: 'down' });
    });
  });
});
