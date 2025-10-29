// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

library PoolTicksCounter {
    /// @dev 该函数计算在tickBefore 和tickAfter 之间会产生gas 成本的初始化tick 的数量。
    /// 当tickBefore和/或tickAfter本身被初始化时，我们是否应该对它们进行计数的逻辑取决于
    /// 交换的方向。如果我们向上交换（tickAfter>tickBefore），我们不想计算tickBefore，但我们会计算
    /// 想要计算tickAfter。如果我们向下交换，则相反。
    function countInitializedTicksCrossed(
        IUniswapV3Pool self,
        int24 tickBefore,
        int24 tickAfter
    ) internal view returns (uint32 initializedTicksCrossed) {
        int16 wordPosLower;
        int16 wordPosHigher;
        uint8 bitPosLower;
        uint8 bitPosHigher;
        bool tickBeforeInitialized;
        bool tickAfterInitialized;

        {
            // 获取交换前后活动刻度的刻度位图中的键和偏移量。
            int16 wordPos = int16((tickBefore / self.tickSpacing()) >> 8);
            uint8 bitPos = uint8((tickBefore / self.tickSpacing()) % 256);

            int16 wordPosAfter = int16((tickAfter / self.tickSpacing()) >> 8);
            uint8 bitPosAfter = uint8((tickAfter / self.tickSpacing()) % 256);

            // 在tickAfter初始化的情况下，我们只想在向下交换时对其进行计数。
            // 如果交换后的可初始化tick被初始化，我们原来的tickAfter是一个
            // 刻度间距的倍数，并且我们向下交换我们知道tickAfter已初始化
            // 我们不应该计算它。
            tickAfterInitialized =
                ((self.tickBitmap(wordPosAfter) & (1 << bitPosAfter)) > 0) &&
                ((tickAfter % self.tickSpacing()) == 0) &&
                (tickBefore > tickAfter);

            // 在tickBefore初始化的情况下，我们只想在向上交换时对其进行计数。
            // 使用与上面相同的逻辑来决定是否应该计算tickBefore。
            tickBeforeInitialized =
                ((self.tickBitmap(wordPos) & (1 << bitPos)) > 0) &&
                ((tickBefore % self.tickSpacing()) == 0) &&
                (tickBefore < tickAfter);

            if (wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter)) {
                wordPosLower = wordPos;
                bitPosLower = bitPos;
                wordPosHigher = wordPosAfter;
                bitPosHigher = bitPosAfter;
            } else {
                wordPosLower = wordPosAfter;
                bitPosLower = bitPosAfter;
                wordPosHigher = wordPos;
                bitPosHigher = bitPos;
            }
        }

        // 通过迭代刻度位图来计算经过的初始化刻度的数量。
        // 我们的第一个掩码应包括下方的勾号及其左侧的所有内容。
        uint256 mask = type(uint256).max << bitPosLower;
        while (wordPosLower <= wordPosHigher) {
            // 如果我们在最后一个刻度位图页面上，请确保我们只计数到我们的
            // 结束勾号。
            if (wordPosLower == wordPosHigher) {
                mask = mask & (type(uint256).max >> (255 - bitPosHigher));
            }

            uint256 masked = self.tickBitmap(wordPosLower) & mask;
            initializedTicksCrossed += countOneBits(masked);
            wordPosLower++;
            // 重置我们的掩码，以便我们在下一次迭代中考虑所有位。
            mask = type(uint256).max;
        }

        if (tickAfterInitialized) {
            initializedTicksCrossed -= 1;
        }

        if (tickBeforeInitialized) {
            initializedTicksCrossed -= 1;
        }

        return initializedTicksCrossed;
    }

    function countOneBits(uint256 x) private pure returns (uint16) {
        uint16 bits = 0;
        while (x != 0) {
            bits++;
            x &= (x - 1);
        }
        return bits;
    }
}
