
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentMarketNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    event Minted(address indexed to, uint256 indexed tokenId, string tokenURI);

    constructor(string memory baseName, string memory baseSymbol) ERC721(baseName, baseSymbol) Ownable(msg.sender) {}

    function mintTo(address to, string memory tokenURI_) external onlyOwner returns (uint256 tokenId) {
        tokenId = _nextTokenId;
        _nextTokenId += 1;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        emit Minted(to, tokenId, tokenURI_);
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }
}
