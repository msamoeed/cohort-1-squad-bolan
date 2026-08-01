import { Controller, Get } from '@nestjs/common';
import { CurrentUser } from './common/firebase/current-user.decorator';
import { Public } from './common/firebase/public.decorator';
import { DecodedIdToken } from 'firebase-admin/auth';

@Controller()
export class AppController {
  @Public()
  @Get('health')
  health(): { status: string } {
    return { status: 'ok' };
  }

  
  @Get('auth/me')
  me(@CurrentUser() user: DecodedIdToken): { uid: string; email?: string } {
    return { uid: user.uid, email: user.email };
  }
}
