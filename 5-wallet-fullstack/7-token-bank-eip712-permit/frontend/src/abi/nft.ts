export const permitNftAbi = [
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
  },
  {
    type: 'function',
    name: 'nextTokenId',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
  },
  {
    type: 'function',
    name: 'tokenURI',
    stateMutability: 'view',
    inputs: [{ type: 'uint256', name: 'tokenId' }],
    outputs: [{ type: 'string', name: '' }],
  },
  {
    type: 'function',
    name: 'ownerOf',
    stateMutability: 'view',
    inputs: [{ type: 'uint256', name: 'tokenId' }],
    outputs: [{ type: 'address', name: '' }],
  },
  {
    type: 'function',
    name: 'isApprovedForAll',
    stateMutability: 'view',
    inputs: [
      { type: 'address', name: 'owner' },
      { type: 'address', name: 'operator' },
    ],
    outputs: [{ type: 'bool', name: '' }],
  },
  {
    type: 'function',
    name: 'setApprovalForAll',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'operator' },
      { type: 'bool', name: 'approved' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'mintTo',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'to' },
      { type: 'string', name: 'tokenURI_' },
    ],
    outputs: [{ type: 'uint256', name: 'tokenId' }],
  },
] as const;
