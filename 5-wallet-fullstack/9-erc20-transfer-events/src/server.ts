import express from "express";
import { getAddress, isAddress } from "viem";
import { config } from "./config";
import { startIndexer, store } from "./indexer";

const app = express();
const port = Number(process.env.PORT ?? 3000);
const tokenAddress = getAddress(config.tokenAddress);

app.use(express.json());
app.use(express.static("public"));

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/transfers/:address", (req, res) => {
  const address = req.params.address;
  if (!isAddress(address)) {
    return res.status(400).json({ error: "invalid address" });
  }

  const limitParam = Number(req.query.limit ?? 100);
  const offsetParam = Number(req.query.offset ?? 0);
  const limit = Number.isFinite(limitParam)
    ? Math.min(Math.max(limitParam, 1), 500)
    : 100;
  const offset = Number.isFinite(offsetParam) && offsetParam > 0 ? offsetParam : 0;

  const transfers = store.getTransfersByAddress(address, limit, offset);
  res.json({
    address: getAddress(address).toLowerCase(),
    token: tokenAddress,
    count: transfers.length,
    transfers,
  });
});

app.listen(port, () => {
  console.log(
    `Server is ready on port ${port}. Token ${tokenAddress}. Polling every ${config.pollIntervalMs}ms.`
  );
});

startIndexer({
  tokenAddress,
  startBlock: config.startBlock,
  pollIntervalMs: config.pollIntervalMs,
  blockBatchSize: config.blockBatchSize,
});
