import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { FirebaseAdminService } from './common/firebase/firebase-admin.service';
import { FirebaseAuthGuard } from './common/firebase/firebase-auth.guard';
import { BusinessStoreService } from './common/firebase/business-store.service';
import { CatalogController } from './catalog/catalog.controller';
import { CatalogService } from './catalog/catalog.service';
import { ContactsController } from './contacts/contacts.controller';
import { ContactsService } from './contacts/contacts.service';
import { InvoiceExtractionController } from './invoice-extraction/invoice-extraction.controller';
import { InvoiceExtractionService } from './invoice-extraction/invoice-extraction.service';
import { ReceivablesController } from './receivables/receivables.controller';
import { ReceivablesService } from './receivables/receivables.service';
import { RemindersController } from './reminders/reminders.controller';
import { RemindersService } from './reminders/reminders.service';
import { UploadsController } from './uploads/uploads.controller';
import { UploadsService } from './uploads/uploads.service';
import { UsersController } from './users/users.controller';
import { UsersService } from './users/users.service';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true })],
  controllers: [AppController, ContactsController, CatalogController, UploadsController, InvoiceExtractionController, ReceivablesController, RemindersController, UsersController],
  providers: [FirebaseAdminService, BusinessStoreService, ContactsService, CatalogService, UploadsService, InvoiceExtractionService, ReceivablesService, RemindersService, UsersService, { provide: APP_GUARD, useClass: FirebaseAuthGuard }],
})
export class AppModule {}
