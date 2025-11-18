# ERC20 transfer indexer

This app uses Viem to index ERC20 `Transfer` logs into SQLite and exposes them through a small REST API.

## Setup
- Copy `.env.example` to `.env` and fill in your RPC URL, token address, and start block.
- Install packages: `pnpm install`.
- Start the app: `pnpm dev` (or `pnpm start` for production). The backend runs on port 3000 and serves the frontend at `http://localhost:3000/`.

## API
- `GET /health` simple health check.
- `GET /transfers/:address?limit=100&offset=0` returns transfers where the address is sender or receiver. `limit` max is 500.

The indexer polls the chain every `POLL_INTERVAL_MS` milliseconds and stores data in the file from `DB_PATH`.
