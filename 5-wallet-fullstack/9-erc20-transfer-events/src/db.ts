import fs from "node:fs";
import path from "node:path";
import Database from "better-sqlite3";

export type TransferRow = {
  txHash: string;
  logIndex: number;
  blockNumber: number;
  blockTime: number;
  from: string;
  to: string;
  value: string;
};

const ensureDbDir = (dbPath: string) => {
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

export function createTransferStore(dbPath: string) {
  ensureDbDir(dbPath);
  const db = new Database(dbPath);
  db.pragma("journal_mode = WAL");

  db.exec(`
    CREATE TABLE IF NOT EXISTS transfers (
      tx_hash TEXT NOT NULL,
      log_index INTEGER NOT NULL,
      block_number INTEGER NOT NULL,
      block_time INTEGER NOT NULL,
      from_address TEXT NOT NULL,
      to_address TEXT NOT NULL,
      value TEXT NOT NULL,
      PRIMARY KEY (tx_hash, log_index)
    );
    CREATE INDEX IF NOT EXISTS idx_transfers_from ON transfers(from_address);
    CREATE INDEX IF NOT EXISTS idx_transfers_to ON transfers(to_address);
    CREATE INDEX IF NOT EXISTS idx_transfers_block ON transfers(block_number);
  `);

  const insertStmt = db.prepare(
    `
    INSERT OR IGNORE INTO transfers
      (tx_hash, log_index, block_number, block_time, from_address, to_address, value)
    VALUES
      (@txHash, @logIndex, @blockNumber, @blockTime, @from, @to, @value)
  `
  );

  const insertMany = db.transaction((rows: TransferRow[]) => {
    for (const row of rows) {
      insertStmt.run(row);
    }
  });

  const maxBlockStmt = db.prepare(
    "SELECT MAX(block_number) as maxBlock FROM transfers"
  );

  const selectByAddress = db.prepare(
    `
    SELECT tx_hash as txHash, log_index as logIndex, block_number as blockNumber,
           block_time as blockTime, from_address as fromAddress,
           to_address as toAddress, value
    FROM transfers
    WHERE lower(from_address) = @address OR lower(to_address) = @address
    ORDER BY block_number DESC, log_index DESC
    LIMIT @limit OFFSET @offset
  `
  );

  type RawRow = {
    txHash: string;
    logIndex: number;
    blockNumber: number;
    blockTime: number;
    fromAddress: string;
    toAddress: string;
    value: string;
  };

  return {
    addTransfers(rows: TransferRow[]) {
      if (!rows.length) return;
      insertMany(rows);
    },
    getHighestBlock(): number | null {
      const result = maxBlockStmt.get() as { maxBlock: number | null };
      return result?.maxBlock ?? null;
    },
    getTransfersByAddress(
      address: string,
      limit: number,
      offset: number = 0
    ): TransferRow[] {
      const rows = selectByAddress.all({
        address: address.toLowerCase(),
        limit,
        offset,
      }) as RawRow[];

      return rows.map((row) => ({
        txHash: row.txHash,
        logIndex: row.logIndex,
        blockNumber: row.blockNumber,
        blockTime: row.blockTime,
        from: row.fromAddress,
        to: row.toAddress,
        value: row.value,
      }));
    },
  };
}
