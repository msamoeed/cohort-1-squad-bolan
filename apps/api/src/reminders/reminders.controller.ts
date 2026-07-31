import { Body, Controller, Param, Post } from '@nestjs/common';
import { DecodedIdToken } from 'firebase-admin/auth';
import { ReminderDraftResponseDto } from '../common/dto/api-response.dto';
import { CreateReminderDraftDto } from '../common/dto/api.dto';
import { CurrentUser } from '../common/firebase/current-user.decorator';
import { RemindersService } from './reminders.service';

@Controller('contacts/:contactId/reminders')
export class RemindersController {
  constructor(private readonly reminders: RemindersService) {}

  @Post('draft')
  draft(
    @CurrentUser() user: DecodedIdToken,
    @Param('contactId') contactId: string,
    @Body() dto: CreateReminderDraftDto,
  ): Promise<ReminderDraftResponseDto> {
    return this.reminders.draft(user.uid, user.uid, contactId, dto);
  }
}
