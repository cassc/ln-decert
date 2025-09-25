## Usages

### Search for 4/5-zero SHA-256 hashes for `<nickname><nonce>`:

```bash
python3 pow_sha256.py <nickname>
```

### Generate RSA keys, sign the proof-of-work payload, and verify:

```bash
python3 rsa_pow.py <nickname>
```

### Mine a short blockchain of three blocks (genesis + 2 mined blocks):

```bash
python3 blockchain_pow.py --blocks 2
```
