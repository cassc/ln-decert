import { promises as fs } from 'node:fs';
import path from 'node:path';

export type PlainStoredWallet = {
  version: 1;
  privateKey: `0x${string}`;
  address: `0x${string}`;
  createdAt: string;
};

export type EncryptedStoredWallet = {
  version: 2;
  address: `0x${string}`;
  createdAt: string;
  encryption: {
    algorithm: 'aes-256-gcm';
    keyDerivation: 'scrypt';
    salt: string; // hex encoded
    iv: string; // hex encoded
    ciphertext: string; // hex encoded
    authTag: string; // hex encoded
  };
};

export type StoredWallet = PlainStoredWallet | EncryptedStoredWallet;

const ensureDir = async (filePath: string) => {
  const dir = path.dirname(filePath);
  await fs.mkdir(dir, { recursive: true });
};

export const walletStore = {
  async read(filePath: string): Promise<StoredWallet | null> {
    try {
      const data = await fs.readFile(filePath, 'utf8');
      const parsed = JSON.parse(data) as Partial<StoredWallet> & {
        version?: number;
        privateKey?: `0x${string}`;
      };

      if (parsed.version === 1 && parsed.privateKey) {
        return parsed as PlainStoredWallet;
      }

      if (parsed.version === 2 && parsed.encryption) {
        return parsed as EncryptedStoredWallet;
      }

      if (!parsed.version && parsed.privateKey && parsed.address && parsed.createdAt) {
        // Backwards compatibility with legacy unversioned plaintext wallets
        return {
          version: 1,
          privateKey: parsed.privateKey,
          address: parsed.address,
          createdAt: parsed.createdAt,
        } satisfies PlainStoredWallet;
      }

      throw new Error('Unsupported wallet file format.');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return null;
      }
      throw error;
    }
  },

  async write(filePath: string, wallet: StoredWallet): Promise<void> {
    await ensureDir(filePath);
    await fs.writeFile(filePath, JSON.stringify(wallet, null, 2), {
      encoding: 'utf8',
      mode: 0o600,
    });
  },
};
