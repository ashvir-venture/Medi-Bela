import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FamilyModule } from '../family/family.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { CloudinaryService } from '../prescriptions/lib/cloudinary.service';

@Module({
  imports: [AuthModule, FamilyModule],
  controllers: [UsersController],
  providers: [UsersService, CloudinaryService],
  exports: [UsersService],
})
export class UsersModule {}
