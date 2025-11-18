#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { ethers } from "ethers";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

const argv = yargs(hideBin(process.argv))
    .usage("$0 --target <address> --file <addresses.json>|--addresses 0x..,0x..")
    .option("target", {
        type: "string",
        demandOption: true,
        describe: "Beneficiary address to generate a proof for"
    })
    .option("file", {
        type: "string",
        describe: "Path to a JSON file containing an array of addresses"
    })
    .option("addresses", {
        type: "string",
        describe: "Comma-separated list of addresses (e.g. addr1,addr2,addr3,...)"
    })
    .option("pretty", {
        type: "boolean",
        default: true,
        describe: "Pretty-print JSON output (disable for calldata-ready output)"
    })
    .check((cli) => {
        if (!cli.file && !cli.addresses) {
            throw new Error("Provide either --file or --addresses");
        }
        if (cli.file && cli.addresses) {
            throw new Error("Use only one source: --file or --addresses");
        }
        return true;
    })
    .help()
    .parseSync();

const target = ethers.getAddress(argv.target);

function loadAddresses() {
    if (argv.file) {
        const resolved = path.resolve(process.cwd(), argv.file);
        const raw = fs.readFileSync(resolved, "utf8");
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed)) {
            throw new Error("File must contain a JSON array of addresses");
        }
        return parsed;
    }
    return argv.addresses.split(",").map((addr) => addr.trim());
}

const addresses = loadAddresses()
    .filter(Boolean)
    .map((addr, idx) => {
        try {
            return ethers.getAddress(addr);
        } catch (err) {
            throw new Error(`Invalid address at index ${idx}: ${addr}`);
        }
    });

const uniqueAddresses = [...new Set(addresses)];

if (uniqueAddresses.length < 4) {
    throw new Error("Provide at least 4 unique addresses to build a tree with more than 2 levels.");
}

const targetIndex = uniqueAddresses.indexOf(target);
if (targetIndex === -1) {
    throw new Error("Target address is not included in the provided whitelist.");
}

const leaves = uniqueAddresses.map((addr) => Buffer.from(addr.slice(2), "hex"));
const tree = new MerkleTree(leaves, keccak256, { hashLeaves: true, sortPairs: true });

const depth = tree.getLayers().length;
if (depth <= 2) {
    throw new Error(
        `Merkle tree depth (${depth}) is not greater than 2. Add more addresses to create a non-trivial tree.`
    );
}

const leafHash = keccak256(Buffer.from(target.slice(2), "hex"));
const proof = tree.getHexProof(leafHash);

if (proof.length === 0) {
    throw new Error("Unable to build a proof. Ensure the target address appears only once.");
}

const jsonOutput = {
    merkleRoot: tree.getHexRoot(),
    proof,
    target,
    targetIndex,
    depth,
    addresses: uniqueAddresses
};

const indentation = argv.pretty ? 2 : 0;
process.stdout.write(JSON.stringify(jsonOutput, null, indentation));
process.stdout.write("\n");
