import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module'; // 👈 1. Import AuthModule
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';

@Module({
  imports: [AuthModule], // 👈 2. Add AuthModule to the imports array
  controllers: [UsersController],
  providers: [UsersService, CloudinaryService],
  exports: [UsersService],
})
export class UsersModule {}
