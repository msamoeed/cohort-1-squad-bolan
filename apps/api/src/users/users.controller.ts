import { Body, Controller, Get, Put } from '@nestjs/common';
import { DecodedIdToken } from 'firebase-admin/auth';
import { UserProfileResponseDto } from '../common/dto/api-response.dto';
import { UpdateUserProfileDto } from '../common/dto/api.dto';
import { CurrentUser } from '../common/firebase/current-user.decorator';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  get(@CurrentUser() user: DecodedIdToken): Promise<UserProfileResponseDto> {
    return this.users.get(user.uid, user.email ?? null);
    
  }

  @Put('me')
  upsert(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: UpdateUserProfileDto,
  ): Promise<UserProfileResponseDto> {
    return this.users.upsert(user.uid, dto, user.email ?? null);
  }
}
