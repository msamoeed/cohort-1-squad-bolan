import { Body, Controller, Post } from '@nestjs/common';
import { DecodedIdToken } from 'firebase-admin/auth';
import { UploadResponseDto } from '../common/dto/api-response.dto';
import { CreateUploadDto } from '../common/dto/api.dto';
import { CurrentUser } from '../common/firebase/current-user.decorator';
import { UploadsService } from './uploads.service';

@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploads: UploadsService) {}

  @Post()
  create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateUploadDto,
  ): Promise<UploadResponseDto> {
    return this.uploads.create(user.uid, dto);
  }
}
