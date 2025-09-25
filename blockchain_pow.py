#!/usr/bin/env python3
"""Minimal blockchain simulation with 4-zero POW difficulty."""

from __future__ import annotations

import argparse
import hashlib
import json
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, Dict, List

DIFFICULTY_PREFIX = "0" * 4


def _current_millis() -> int:
    return int(time.time() * 1000)


def _random_id() -> str:
    return uuid.uuid4().hex


@dataclass
class Block:
    index: int
    timestamp: int
    transactions: List[Dict[str, Any]]
    proof: int
    previous_hash: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "index": self.index,
            "timestamp": self.timestamp,
            "transactions": self.transactions,
            "proof": self.proof,
            "previous_hash": self.previous_hash,
        }


@dataclass
class Blockchain:
    pending_transactions: List[Dict[str, Any]] = field(default_factory=list)
    chain: List[Block] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not self.chain:
            self._create_genesis_block()

    @staticmethod
    def compute_hash(
        index: int,
        timestamp: int,
        transactions: List[Dict[str, Any]],
        proof: int,
        previous_hash: str,
    ) -> str:
        block_dict = {
            "index": index,
            "timestamp": timestamp,
            "transactions": transactions,
            "proof": proof,
            "previous_hash": previous_hash,
        }
        block_string = json.dumps(block_dict, sort_keys=True, separators=(",", ":")).encode("utf-8")
        return hashlib.sha256(block_string).hexdigest()

    @staticmethod
    def hash_block(block: Block) -> str:
        return Blockchain.compute_hash(
            block.index,
            block.timestamp,
            block.transactions,
            block.proof,
            block.previous_hash,
        )

    @staticmethod
    def find_proof(
        index: int,
        timestamp: int,
        transactions: List[Dict[str, Any]],
        previous_hash: str,
    ) -> tuple[int, str]:
        proof = 0
        while True:
            digest = Blockchain.compute_hash(index, timestamp, transactions, proof, previous_hash)
            if digest.startswith(DIFFICULTY_PREFIX):
                return proof, digest
            proof += 1

    @property
    def last_block(self) -> Block:
        return self.chain[-1]

    def _create_genesis_block(self) -> None:
        index = 1
        timestamp = _current_millis()
        transactions: List[Dict[str, Any]] = []
        proof, _ = self.find_proof(index, timestamp, transactions, previous_hash="0")
        block = Block(
            index=index,
            timestamp=timestamp,
            transactions=transactions,
            proof=proof,
            previous_hash="0",
        )
        self.chain.append(block)

    def create_block(
        self,
        *,
        proof: int,
        previous_hash: str,
        timestamp: int,
        transactions: List[Dict[str, Any]],
    ) -> Block:
        block = Block(
            index=len(self.chain) + 1,
            timestamp=timestamp,
            transactions=transactions,
            proof=proof,
            previous_hash=previous_hash,
        )
        self.chain.append(block)
        return block

    def add_random_transaction(self) -> None:
        self.pending_transactions.append(
            {
                "sender": _random_id(),
                "recipient": _random_id(),
                "amount": 1,
            }
        )

    def mine_block(self) -> Block:
        self.add_random_transaction()
        transactions = [tx.copy() for tx in self.pending_transactions]
        timestamp = _current_millis()
        index = len(self.chain) + 1
        previous_hash = self.hash_block(self.last_block)
        proof, _ = self.find_proof(index, timestamp, transactions, previous_hash)
        block = self.create_block(
            proof=proof,
            previous_hash=previous_hash,
            timestamp=timestamp,
            transactions=transactions,
        )
        self.pending_transactions.clear()
        return block


def mine_blocks(block_count: int) -> List[Block]:
    blockchain = Blockchain()
    for _ in range(block_count):
        blockchain.mine_block()
    return list(blockchain.chain)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Mine blocks on a minimal blockchain with 4-leading-zero POW"
    )
    parser.add_argument(
        "--blocks",
        type=int,
        default=3,
        help="Number of blocks to mine (excluding genesis)",
    )
    args = parser.parse_args()

    chain = mine_blocks(args.blocks)

    for block in chain:
        data = block.to_dict()
        data["hash"] = Blockchain.hash_block(block)
        print(json.dumps(data, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
