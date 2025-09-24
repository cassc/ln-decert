import hashlib
import time


def compute_hash(nickname: str, nonce: int) -> tuple[str, str]:
    content = f"{nickname}{nonce}"
    digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
    return content, digest


def find_target(nickname: str, start_nonce: int, zeros: int) -> tuple[int, str, str, float]:
    prefix = "0" * zeros
    nonce = start_nonce
    start_time = time.perf_counter()
    while True:
        content, digest = compute_hash(nickname, nonce)
        if digest.startswith(prefix):
            elapsed = time.perf_counter() - start_time
            return nonce, content, digest, elapsed
        nonce += 1


def main() -> None:
    results = []
    nonce = 0
    for zeros in (4, 5):
        found_nonce, content, digest, elapsed = find_target('cassc', nonce, zeros)
        results.append((zeros, elapsed, content, digest))
        nonce = found_nonce + 1

    for zeros, elapsed, content, digest in results:
        print(f"target: {zeros} leading zeros")
        print(f"time: {elapsed:.3f}s")
        print(f"content: {content}")
        print(f"hash: {digest}\n")


if __name__ == "__main__":
    main()
