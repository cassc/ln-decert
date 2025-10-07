export const marketAbi = [
  {
    type: 'function',
    name: 'paymentToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
  },
  {
    type: 'function',
    name: 'whitelistSigner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
  },
  {
    type: 'function',
    name: 'setWhitelistSigner',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'newSigner' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'list',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'nft' },
      { type: 'uint256', name: 'tokenId' },
      { type: 'uint256', name: 'price' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'unlist',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'nft' },
      { type: 'uint256', name: 'tokenId' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'getListing',
    stateMutability: 'view',
    inputs: [
      { type: 'address', name: 'nft' },
      { type: 'uint256', name: 'tokenId' },
    ],
    outputs: [
      {
        type: 'tuple',
        name: '',
        components: [
          { type: 'address', name: 'seller' },
          { type: 'uint256', name: 'price' },
        ],
      },
    ],
  },
  {
    type: 'function',
    name: 'hashPermitBuy',
    stateMutability: 'view',
    inputs: [
      { type: 'address', name: 'buyer' },
      { type: 'address', name: 'nft' },
      { type: 'uint256', name: 'tokenId' },
      { type: 'uint256', name: 'price' },
      { type: 'uint256', name: 'deadline' },
    ],
    outputs: [{ type: 'bytes32', name: '' }],
  },
  {
    type: 'function',
    name: 'permitBuy',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'nft' },
      { type: 'uint256', name: 'tokenId' },
      { type: 'uint256', name: 'price' },
      { type: 'uint256', name: 'deadline' },
      { type: 'bytes', name: 'signature' },
    ],
    outputs: [],
  },
] as const;
