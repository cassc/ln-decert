#!/usr/bin/env python3
"""Generate RSA keys, perform 4-zero POW, sign and verify the content."""

from __future__ import annotations

import argparse
import base64
import hashlib
import time

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa


def compute_hash(nickname: str, nonce: int) -> tuple[str, str]:
    payload = f"{nickname}{nonce}"
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    return payload, digest


def find_pow(nickname: str, start_nonce: int, zeros: int = 4) -> tuple[int, str, str, float]:
    target_prefix = "0" * zeros
    nonce = start_nonce
    start_time = time.perf_counter()
    while True:
        payload, digest = compute_hash(nickname, nonce)
        if digest.startswith(target_prefix):
            elapsed = time.perf_counter() - start_time
            return nonce, payload, digest, elapsed
        nonce += 1


def generate_rsa_keypair() -> tuple[rsa.RSAPrivateKey, rsa.RSAPublicKey]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key, private_key.public_key()


def serialize_key(key, is_private: bool) -> str:
    if is_private:
        encoding = serialization.Encoding.PEM
        format_ = serialization.PrivateFormat.PKCS8
        return key.private_bytes(
            encoding=encoding,
            format=format_,
            encryption_algorithm=serialization.NoEncryption(),
        ).decode("ascii")

    return key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode("ascii")


def sign_payload(private_key: rsa.RSAPrivateKey, payload: str) -> bytes:
    return private_key.sign(
        payload.encode("utf-8"),
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
        hashes.SHA256(),
    )


def verify_signature(
    public_key: rsa.RSAPublicKey, payload: str, signature: bytes
) -> None:
    public_key.verify(
        signature,
        payload.encode("utf-8"),
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
        hashes.SHA256(),
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Generate RSA keys, discover a 4-leading-zero SHA-256 POW nonce, sign and verify the payload"
        )
    )
    parser.add_argument("nickname", help="Nickname to concatenate with nonce for POW")
    parser.add_argument(
        "--start-nonce", type=int, default=0, help="Starting nonce for the POW search"
    )
    args = parser.parse_args()

    private_key, public_key = generate_rsa_keypair()

    nonce, payload, digest, elapsed = find_pow(args.nickname, args.start_nonce)

    signature = sign_payload(private_key, payload)
    verify_signature(public_key, payload, signature)

    print("RSA Private Key:")
    print(serialize_key(private_key, is_private=True))
    print("RSA Public Key:")
    print(serialize_key(public_key, is_private=False))

    print("POW Result:")
    print(f"nickname: {args.nickname}")
    print(f"nonce: {nonce}")
    print(f"payload: {payload}")
    print(f"hash: {digest}")
    print(f"time: {elapsed:.3f}s")

    print("Signature (base64):")
    print(base64.b64encode(signature).decode("ascii"))
    print("Verification: success")


if __name__ == "__main__":
    main()
