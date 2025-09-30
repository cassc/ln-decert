# Token Bank Project

This repo holds the Bank smart contract and the React frontend.

## Contracts

The Foundry project lives in the repo root. Run tests with:
```bash
forge test
```
You can deploy the Bank contract with your own script or use Foundry `forge script`.

## Frontend

The frontend code sits in `frontend/`.

### Configure

1. Copy the env file:
   ```bash
   cd frontend
   cp .env.example .env.local
   ```
2. Fill the Bank contract address, chain id, and RPC URL in `.env.local`. The sample file points to Sepolia (chain id `11155111`, RPC `https://rpc.sepolia.org`).

### Install deps

With npm:
```bash
npm install
```

With pnpm (after you install pnpm, see below):
```bash
pnpm install
```

### Run dev server
```bash
npm run dev
# or
pnpm run dev
```
The app opens at `http://localhost:5173`.

### Build
```bash
npm run build
# or
pnpm run build
```

## Install pnpm without sudo

Corepack tries to write to `/usr/bin`, so it fails on this machine. Use the npm global prefix to put pnpm into your home folder:
```bash
npm install -g pnpm --prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
```
Add the export line to your shell config so it runs every time.

Now you can run `pnpm --version` and use pnpm commands inside `frontend/`.
