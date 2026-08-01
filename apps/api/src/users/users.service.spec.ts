import { NotFoundException } from '@nestjs/common';
import { FirebaseAdminService } from '../common/firebase/firebase-admin.service';
import { UsersService } from './users.service';

describe('UsersService', () => {
  it('returns a mapped profile when the document exists', async () => {
    const service = new UsersService(
      mockFirebase({
        exists: true,
        data: {
          name: 'Ahmed Khan',
          phone: '+923001234567',
          createdAt: '2026-07-01T00:00:00.000Z',
          updatedAt: '2026-07-02T00:00:00.000Z',
        },
      }),
    );

    await expect(service.get('uid-1', 'ahmed@example.com')).resolves.toEqual({
      uid: 'uid-1',
      email: 'ahmed@example.com',
      name: 'Ahmed Khan',
      phone: '+923001234567',
      createdAt: '2026-07-01T00:00:00.000Z',
      updatedAt: '2026-07-02T00:00:00.000Z',
    });
  });

  it('throws NotFoundException when the profile is missing', async () => {
    const service = new UsersService(mockFirebase({ exists: false }));
    await expect(service.get('uid-1', null)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('creates a profile document on first upsert', async () => {
    const set = jest.fn().mockResolvedValue(undefined);
    const get = jest
      .fn()
      .mockResolvedValueOnce({ exists: false })
      .mockResolvedValueOnce({
        exists: true,
        data: () => ({
          name: 'Ahmed Khan',
          phone: '+923001234567',
          createdAt: '2026-07-01T00:00:00.000Z',
          updatedAt: '2026-07-01T00:00:00.000Z',
        }),
      });
    const update = jest.fn();
    const service = new UsersService(
      mockFirebase({ exists: false, set, get, update }),
    );

    await expect(
      service.upsert(
        'uid-1',
        { name: 'Ahmed Khan', phone: '+923001234567' },
        'ahmed@example.com',
      ),
    ).resolves.toMatchObject({
      uid: 'uid-1',
      email: 'ahmed@example.com',
      name: 'Ahmed Khan',
      phone: '+923001234567',
    });
    expect(set).toHaveBeenCalledTimes(1);
    expect(update).not.toHaveBeenCalled();
    expect(set.mock.calls[0][0]).toMatchObject({
      name: 'Ahmed Khan',
      phone: '+923001234567',
    });
    expect(set.mock.calls[0][0]).toHaveProperty('createdAt');
    expect(set.mock.calls[0][0]).toHaveProperty('updatedAt');
  });

  it('updates an existing profile without overwriting createdAt', async () => {
    const update = jest.fn().mockResolvedValue(undefined);
    const set = jest.fn();
    const get = jest
      .fn()
      .mockResolvedValueOnce({ exists: true })
      .mockResolvedValueOnce({
        exists: true,
        data: () => ({
          name: 'Ahmed Updated',
          phone: '+923009999999',
          createdAt: '2026-07-01T00:00:00.000Z',
          updatedAt: '2026-07-03T00:00:00.000Z',
        }),
      });
    const service = new UsersService(
      mockFirebase({ exists: true, set, get, update }),
    );

    await expect(
      service.upsert(
        'uid-1',
        { name: 'Ahmed Updated', phone: '+923009999999' },
        'ahmed@example.com',
      ),
    ).resolves.toMatchObject({
      name: 'Ahmed Updated',
      phone: '+923009999999',
      createdAt: '2026-07-01T00:00:00.000Z',
    });
    expect(update).toHaveBeenCalledTimes(1);
    expect(set).not.toHaveBeenCalled();
    expect(update.mock.calls[0][0]).toMatchObject({
      name: 'Ahmed Updated',
      phone: '+923009999999',
    });
    expect(update.mock.calls[0][0]).not.toHaveProperty('createdAt');
    expect(update.mock.calls[0][0]).toHaveProperty('updatedAt');
  });
});

function mockFirebase(options: {
  exists: boolean;
  data?: Record<string, unknown>;
  set?: jest.Mock;
  get?: jest.Mock;
  update?: jest.Mock;
}): FirebaseAdminService {
  const get =
    options.get ??
    jest.fn().mockResolvedValue({
      exists: options.exists,
      data: () => options.data ?? {},
    });
  const set = options.set ?? jest.fn().mockResolvedValue(undefined);
  const update = options.update ?? jest.fn().mockResolvedValue(undefined);

  return {
    firestore: {
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          get,
          set,
          update,
        })),
      })),
    },
  } as unknown as FirebaseAdminService;
}
