// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 标题 提供从工厂、代币和费用中获取矿池地址的函数
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @notice 矿池的识别键
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice 返回 PoolKey：具有匹配费用水平的已订购代币
    /// 参数 tokenA 池中的第一个令牌，未排序
    /// 参数 tokenB 池中的第二个令牌，未排序
    /// 参数 Fee 矿池的费用水平
    /// 返回 Poolkey 带有有序 token0 和 token1 分配的池详细信息
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice 给定工厂和 PoolKey 确定性地计算池地址
    /// 参数 工厂 Uniswap V3 工厂合约地址
    /// 参数 密钥 PoolKey
    /// 返回 pool V3池的合约地址
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        keccak256(abi.encode(key.token0, key.token1, key.fee)),
                        POOL_INIT_CODE_HASH
                    )
                )
            )
        );
    }
}
