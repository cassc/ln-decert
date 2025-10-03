import { promises as fs } from 'node:fs';
import path from 'node:path';

export type StoredWallet = {
  privateKey: `0x${string}`;
  address: `0x${string}`;
  createdAt: string;
};

const ensureDir = async (filePath: string) => {
  const dir = path.dirname(filePath);
  await fs.mkdir(dir, { recursive: true });
};

export const walletStore = {
  async read(filePath: string): Promise<StoredWallet | null> {
    try {
      const data = await fs.readFile(filePath, 'utf8');
      return JSON.parse(data) as StoredWallet;
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
