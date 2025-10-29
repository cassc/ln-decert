// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

/// @title 甲骨文
/// @notice 提供对各种系统设计有用的价格和流动性数据
/// @dev 存储的预言机数据实例（“观察值”）收集在预言机数组中
/// 每个池都使用长度为 1 的 oracle 数组进行初始化。任何人都可以向 SSTORE 付费以增加
/// oracle 数组的最大长度。当阵列完全填充时，将添加新的插槽。
/// 当 oracle 数组的完整长度被填充时，观察结果将被覆盖。
/// 通过将 0 传递给observe()，可以获得最新的观察结果，与 oracle 数组的长度无关
library Oracle {
    struct Observation {
        // 观察的区块时间戳
        uint32 blockTimestamp;
        // 滴答累加器，即滴答 * 自池首次初始化以来经过的时间
        int56 tickCumulative;
        // 每个流动性的秒数，即自池首次初始化以来经过的秒数/ max(1,流动性)
        uint160 secondsPerLiquidityCumulativeX128;
        // 观察是否已初始化
        bool initialized;
    }

    /// @notice 考虑到时间的推移以及当前的价格变动和流动性值，将先前的观察结果转换为新的观察结果
    /// @dev blockTimestamp_必须_按时间顺序等于或大于last.blockTimestamp，对于 0 或 1 次溢出是安全的
    /// @param 最后要转换的指定观察值
    /// @param blockTimestamp 新观察的时间戳
    /// @param 刻度 新观察时的活动刻度
    /// @param 流动性 新观察时范围内的总流动性
    /// @return 观察 新填充的观察
    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns (Observation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * delta,
                secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
                initialized: true
            });
    }

    /// @notice 通过写入第一个槽来初始化 oracle 数组。在观察数组的生命周期中调用一次
    /// @param self 存储的oracle数组
    /// @param time oracle初始化的时间，通过block.timestamp截断为uint32
    /// @return 基数 oracle 数组中填充元素的数量
    /// @return cardinalityNext oracle 数组的新长度，与人口无关
    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({
            blockTimestamp: time,
            tickCumulative: 0,
            secondsPerLiquidityCumulativeX128: 0,
            initialized: true
        });
        return (1, 1);
    }

    /// @notice 将 oracle 观察结果写入数组
    /// @dev 每个块最多可写一次。索引代表最近写入的元素。基数和索引必须在外部进行跟踪。
    /// 如果索引位于允许数组长度的末尾（根据基数），则下一个基数
    /// 大于当前基数，基数可能会增加。创建此限制是为了保持顺序。
    /// @param self 存储的oracle数组
    /// @param index 最近写入观测值数组的观测值的索引
    /// @param blockTimestamp 新观察的时间戳
    /// @param 刻度 新观察时的活动刻度
    /// @param 流动性 新观察时范围内的总流动性
    /// @param 基数 oracle 数组中填充元素的数量
    /// @param cardinalityNext oracle 数组的新长度，与人口无关
    /// @return indexUpdated oracle 数组中最近写入的元素的新索引
    /// @return cardinalityUpdated oracle 数组的新基数
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // 如果我们已经在这个块中写了一个观察，则提前返回
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // 如果条件合适，我们可以提高基数
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, blockTimestamp, tick, liquidity);
    }

    /// @notice 准备 oracle 数组来存储最多“下一个”观察结果
    /// @param self 存储的oracle数组
    /// @param current oracle 数组当前的下一个基数
    /// @param next 建议的下一个基数将填充到 oracle 数组中
    /// @return next 将填充到 oracle 数组中的下一个基数
    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        require(current > 0, 'I');
        // 如果传递的下一个值不大于当前的下一个值，则无操作
        if (next <= current) return current;
        // 存储在每个槽中以防止交换中出现新的 SSTORE
        // 该数据不会被使用，因为初始化的布尔值仍然为 false
        for (uint16 i = current; i < next; i++) self[i].blockTimestamp = 1;
        return next;
    }

    /// @notice 32 位时间戳比较器
    /// @dev 对于 0 或 1 次溢出是安全的，a 和 b_必须_按时间顺序早于或等于 time
    /// @param time 时间戳被截断为 32 位
    /// @param a 比较时间戳，从中确定“时间”的相对位置
    /// @param b 从中确定`time`的相对位置
    /// @return bool 按时间顺序 `a` 是否 <= `b`
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // 如果没有溢出，则无需调整
        if (a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }

    /// @notice 获取目标 beforeOrAt 和 atOrAfter 的观测值，即满足 [beforeOrAt, atOrAfter] 的位置。
    /// 结果可能是相同的观察结果，也可能是相邻的观察结果。
    /// @dev 答案必须包含在数组中，当目标位于存储的观测值内时使用
    /// 边界：比最近的观察值更老，并且比最旧的观察值更年轻，或者年龄相同
    /// @param self 存储的oracle数组
    /// @param time 当前区块.timestamp
    /// @param target 保留观察的时间戳
    /// @param index 最近写入观测值数组的观测值的索引
    /// @param 基数 oracle 数组中填充元素的数量
    /// @return beforeOrAt 在目标之前或处记录的观察结果
    /// @return atOrAfter 在目标处或之后记录的观察结果
    function binarySearch(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // oldest observation
        uint256 r = l + cardinality - 1; // newest observation
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % cardinality];

            // 我们已经到达了一个未初始化的刻度，继续搜索更高的位置（最近）
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // 检查我们是否找到了答案！
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    /// @notice 获取给定目标 beforeOrAt 和 atOrAfter 的观测值，即满足 [beforeOrAt, atOrAfter] 的位置
    /// @dev 假设至少有 1 个初始化观察。
    /// 由observeSingle() 用于计算给定块时间戳的反事实累加器值。
    /// @param self 存储的oracle数组
    /// @param time 当前区块.timestamp
    /// @param target 保留观察的时间戳
    /// @param 刻度 返回或模拟观察时的活动刻度
    /// @param index 最近写入观测值数组的观测值的索引
    /// @param 流动性 调用时的总流动性
    /// @param 基数 oracle 数组中填充元素的数量
    /// @return beforeOrAt 在给定时间戳或之前发生的观察
    /// @return atOrAfter 在给定时间戳或之后发生的观察
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // 在最新观察之前乐观地设定
        beforeOrAt = self[index];

        // 如果目标按时间顺序位于最新观测值或之后，我们可以提前返回
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                // 如果最新的观察等于目标，我们在同一个块中，所以我们可以忽略 atOrAfter
                return (beforeOrAt, atOrAfter);
            } else {
                // 否则，我们需要改造
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidity));
            }
        }

        // 现在，将之前设置为最旧的观察值
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // 确保目标按时间顺序位于最旧的观察值或之后
        require(lte(time, beforeOrAt.blockTimestamp, target), 'OLD');

        // 如果我们已经到达这一点，我们必须进行二分搜索
        return binarySearch(self, time, target, index, cardinality);
    }

    /// @dev 如果所需观察时间戳或之前的观察不存在，则恢复。
    /// 0 可以作为“secondsAgo”传递以返回当前累积值。
    /// 如果使用介于两个观察值之间的时间戳进行调用，则返回反事实累加器值
    /// 正好是两次观察之间的时间戳。
    /// @param self 存储的oracle数组
    /// @param time 当前区块时间戳
    /// @param timesAgo 回顾的时间量（以秒为单位），此时返回观察结果
    /// @param 勾号 当前勾号
    /// @param index 最近写入观测值数组的观测值的索引
    /// @param 流动性 当前池内流动性
    /// @param 基数 oracle 数组中填充元素的数量
    /// @return tickCumulative 自池首次初始化以来经过的tick *时间，截至“secondsAgo”
    /// @return SecondsPerLiquidityCumulativeX128 自池首次初始化以来经过的时间/ max(1, 流动性)，截至“secondsAgo”
    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
        if (secondsAgo == 0) {
            Observation memory last = self[index];
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidity);
            return (last.tickCumulative, last.secondsPerLiquidityCumulativeX128);
        }

        uint32 target = time - secondsAgo;

        (Observation memory beforeOrAt, Observation memory atOrAfter) =
            getSurroundingObservations(self, time, target, tick, index, liquidity, cardinality);

        if (target == beforeOrAt.blockTimestamp) {
            // 我们在左边界
            return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
        } else if (target == atOrAfter.blockTimestamp) {
            // 我们处于正确的边界
            return (atOrAfter.tickCumulative, atOrAfter.secondsPerLiquidityCumulativeX128);
        } else {
            // 我们在中间
            uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
            uint32 targetDelta = target - beforeOrAt.blockTimestamp;
            return (
                beforeOrAt.tickCumulative +
                    ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / observationTimeDelta) *
                    targetDelta,
                beforeOrAt.secondsPerLiquidityCumulativeX128 +
                    uint160(
                        (uint256(
                            atOrAfter.secondsPerLiquidityCumulativeX128 - beforeOrAt.secondsPerLiquidityCumulativeX128
                        ) * targetDelta) / observationTimeDelta
                    )
            );
        }
    }

    /// @notice 返回“secondsAgos”数组中给定时间几秒前的累加器值
    /// @dev 如果 `secondsAgos` > 最旧的观察值则恢复
    /// @param self 存储的oracle数组
    /// @param time 当前区块.timestamp
    /// @param timesAgos 每次回顾的时间量（以秒为单位），此时返回观察结果
    /// @param 勾号 当前勾号
    /// @param index 最近写入观测值数组的观测值的索引
    /// @param 流动性 当前池内流动性
    /// @param 基数 oracle 数组中填充元素的数量
    /// @return tickCumulatives 自池首次初始化以来经过的tick *时间，截至每个“secondsAgo”
    /// @return SecondsPerLiquidityCumulativeX128s 自池首次初始化以来，截至每个“SecondsAgo”的累计秒数 / max(1, 流动性)
    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        require(cardinality > 0, 'I');

        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            (tickCumulatives[i], secondsPerLiquidityCumulativeX128s[i]) = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                liquidity,
                cardinality
            );
        }
    }
}
