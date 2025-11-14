#!/usr/bin/env node
import process from "node:process";
import { ethers } from "ethers";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

const argv = yargs(hideBin(process.argv))
    .usage("$0 --private-key <hex> --token <addr> --spender <addr> --value <uint> --deadline <timestamp> --chain-id <id>")
    .version(false)
    .option("private-key", {
        type: "string",
        demandOption: true,
        describe: "Signer private key (hex, 0x-prefixed)"
    })
    .option("token", {
        type: "string",
        demandOption: true,
        describe: "ERC20Permit token address"
    })
    .option("spender", {
        type: "string",
        demandOption: true,
        describe: "Spender allowed to use the permit"
    })
    .option("value", {
        type: "string",
        demandOption: true,
        describe: "Allowance amount (wei)"
    })
    .option("deadline", {
        type: "number",
        demandOption: true,
        describe: "Permit expiry timestamp (seconds)"
    })
    .option("chain-id", {
        type: "number",
        demandOption: true,
        describe: "Chain ID for the signing domain"
    })
    .option("nonce", {
        type: "number",
        describe: "Override nonce; if omitted script tries to fetch via RPC"
    })
    .option("rpc", {
        type: "string",
        describe: "Optional RPC URL to fetch nonce/name/version from the token"
    })
    .option("name", {
        type: "string",
        describe: "Token name override (falls back to on-chain data or 'PermitToken')"
    })
    .option("version", {
        type: "string",
        default: "1",
        describe: "Token version override (falls back to on-chain data or '1')"
    })
    .option("pretty", {
        type: "boolean",
        default: true,
        describe: "Pretty-print JSON output"
    })
    .help()
    .parseSync();

const wallet = new ethers.Wallet(argv["private-key"]);
const owner = wallet.address;
const token = ethers.getAddress(argv.token);
const spender = ethers.getAddress(argv.spender);
const value = BigInt(argv.value);
const deadline = BigInt(argv.deadline);

const provider = argv.rpc ? new ethers.JsonRpcProvider(argv.rpc) : null;
const erc20PermitAbi = [
    "function nonces(address) view returns (uint256)",
    "function name() view returns (string)",
    "function version() view returns (string)"
];
const contract = provider ? new ethers.Contract(token, erc20PermitAbi, provider) : null;

async function getNonce() {
    if (argv.nonce !== undefined) {
        return BigInt(argv.nonce);
    }
    if (!contract) {
        return 0n;
    }
    try {
        return ethers.toBigInt(await contract.nonces(owner));
    } catch {
        return 0n;
    }
}

async function getName() {
    if (argv.name) return argv.name;
    if (!contract) return "PermitToken";
    try {
        return await contract.name();
    } catch {
        return "PermitToken";
    }
}

async function getVersion() {
    if (argv.version) return argv.version;
    if (!contract) return "1";
    try {
        return await contract.version();
    } catch {
        return "1";
    }
}

const [nonce, name, version] = await Promise.all([getNonce(), getName(), getVersion()]);

const domain = {
    name,
    version,
    chainId: argv["chain-id"],
    verifyingContract: token
};

const types = {
    Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" }
    ]
};

const message = {
    owner,
    spender,
    value,
    nonce,
    deadline
};

const signature = await wallet.signTypedData(domain, types, message);
const sig = ethers.Signature.from(signature);

const output = {
    domain,
    message: {
        ...message,
        value: message.value.toString(),
        nonce: message.nonce.toString(),
        deadline: message.deadline.toString()
    },
    signature: {
        v: sig.v,
        r: sig.r,
        s: sig.s
    }
};

process.stdout.write(JSON.stringify(output, null, argv.pretty ? 2 : 0));
process.stdout.write("\n");
