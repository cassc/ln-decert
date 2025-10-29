// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './INonfungiblePositionManager.sol';

/// 标题 通过 URI 描述位置 NFT 代币
interface INonfungibleTokenPositionDescriptor {
    /// @notice 生成描述职位管理器特定令牌 ID 的 URI
    /// @dev 请注意，此 URI 可能是直接内联 JSON 内容的 data: URI
    /// 参数 positionManager 描述令牌的仓位管理器
    /// 参数 tokenId 要为其生成描述的令牌的 ID，该 ID 可能无效
    /// 返回 符合 ERC721 的元数据的 URI
    function tokenURI(INonfungiblePositionManager positionManager, uint256 tokenId)
        external
        view
        returns (string memory);
}
