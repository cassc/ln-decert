import { existsSync } from 'node:fs';
import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'node:crypto';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import type { Account } from 'viem';
import { appConfig } from '../config';
import { walletStore } from './walletStore';

type EncryptionArtifacts = {
  salt: string;
  iv: string;
  ciphertext: string;
  authTag: string;
};

const AES_ALGORITHM = 'aes-256-gcm';
const KEY_DERIVATION = 'scrypt';

const deriveKey = (password: string, salt: Buffer) =>
  scryptSync(password, salt, 32, { N: 2 ** 14, r: 8, p: 1 });

const encryptPrivateKey = (
  privateKey: `0x${string}`,
  password: string
): EncryptionArtifacts => {
  const salt = randomBytes(16);
  const iv = randomBytes(12);
  const key = deriveKey(password, salt);
  const cipher = createCipheriv(AES_ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(Buffer.from(privateKey.slice(2), 'hex')),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();

  return {
    salt: salt.toString('hex'),
    iv: iv.toString('hex'),
    ciphertext: encrypted.toString('hex'),
    authTag: authTag.toString('hex'),
  };
};

const decryptPrivateKey = (
  artifacts: EncryptionArtifacts,
  password: string
): `0x${string}` => {
  const { salt, iv, ciphertext, authTag } = artifacts;
  const key = deriveKey(password, Buffer.from(salt, 'hex'));
  const decipher = createDecipheriv(AES_ALGORITHM, key, Buffer.from(iv, 'hex'));
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));

  try {
    const decrypted = Buffer.concat([
      decipher.update(Buffer.from(ciphertext, 'hex')),
      decipher.final(),
    ]);
    return `0x${decrypted.toString('hex')}`;
  } catch (error) {
    throw new Error('Failed to decrypt wallet. Ensure the password is correct.');
  }
};

export const createWallet = async ({
  force = false,
  password,
}: {
  force?: boolean;
  password?: string;
} = {}) => {
  const walletPath = appConfig.keyStorePath;
  if (!force && existsSync(walletPath)) {
    throw new Error(`Wallet file already exists at ${walletPath}. Use --force to overwrite.`);
  }

  const privateKey = generatePrivateKey();
  const account = privateKeyToAccount(privateKey);
  const createdAt = new Date().toISOString();

  if (password && password.length === 0) {
    throw new Error('Password cannot be empty when provided.');
  }

  if (password) {
    const encryption = encryptPrivateKey(privateKey, password);
    await walletStore.write(walletPath, {
      version: 2,
      address: account.address,
      createdAt,
      encryption: {
        algorithm: AES_ALGORITHM,
        keyDerivation: KEY_DERIVATION,
        ...encryption,
      },
    });

    return { account, privateKey: undefined, walletPath, encrypted: true as const };
  }

  await walletStore.write(walletPath, {
    version: 1,
    privateKey,
    address: account.address,
    createdAt,
  });

  return { account, privateKey, walletPath, encrypted: false as const };
};

export const loadStoredAccount = async ({
  password,
}: { password?: string } = {}): Promise<Account> => {
  const walletPath = appConfig.keyStorePath;
  const stored = await walletStore.read(walletPath);
  if (!stored) {
    throw new Error(`Wallet file not found at ${walletPath}. Run the generate command first.`);
  }

  if (stored.version === 2) {
    if (!password) {
      throw new Error('Wallet is password protected. Provide --password to decrypt it.');
    }

    const privateKey = decryptPrivateKey(stored.encryption, password);
    return privateKeyToAccount(privateKey);
  }

  return privateKeyToAccount(stored.privateKey);
};
