import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { DecodedIdToken } from 'firebase-admin/auth';
import { InvoiceExtractionResponseDto } from '../common/dto/api-response.dto';
import { CreateExtractionDto } from '../common/dto/api.dto';
import { CurrentUser } from '../common/firebase/current-user.decorator';
import { InvoiceExtractionService } from './invoice-extraction.service';

@Controller('invoice-extractions')
export class InvoiceExtractionController {
  constructor(private readonly extractions: InvoiceExtractionService) {}

  @Post()
  create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateExtractionDto,
  ): Promise<InvoiceExtractionResponseDto> {
    return this.extractions.create(user.uid, dto);
  }

  @Get(':id')
  get(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<InvoiceExtractionResponseDto> {
    return this.extractions.get(user.uid, id);
  }
}
