// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleLeverageDEX
 * @notice 基于虚拟自动做市商（vAMM）的简单杠杆交易所
 * @dev 该合约实现了一个虚拟的 AMM，允许用户开设多头或空头杠杆仓位
 *
 * 核心功能：
 * - 用户可以使用 USDC 作为保证金开设杠杆仓位
 * - 支持多头（做多）和空头（做空）两种方向
 * - 使用虚拟资产池（vETH 和 vUSDC）通过恒定乘积公式计算价格
 * - 当仓位亏损超过 80% 保证金时，可被第三方清算
 *
 * 虚拟 AMM 原理：
 * - 维护虚拟的 ETH 和 USDC 储备量
 * - 遵循恒定乘积公式：vK = vETHAmount * vUSDCAmount
 * - 所有交易仅影响虚拟储备，不涉及真实资产转移
 */
contract SimpleLeverageDEX {
    /// @notice 虚拟资产池的恒定乘积 K 值
    /// @dev K = vETHAmount * vUSDCAmount，在整个合约生命周期中保持不变
    uint256 public vK;

    /// @notice 虚拟 ETH 储备量
    /// @dev 随着用户开平仓而动态调整
    uint256 public vETHAmount;

    /// @notice 虚拟 USDC 储备量
    /// @dev 随着用户开平仓而动态调整
    uint256 public vUSDCAmount;

    /// @notice USDC 代币合约地址
    /// @dev 用户使用 USDC 作为保证金
    IERC20 public immutable USDC;

    /// @notice 清算阈值（百分比）
    /// @dev 当仓位亏损达到保证金的 80% 时可以被清算
    uint256 public constant LIQUIDATION_THRESHOLD = 80; // percent

    /**
     * @notice 用户仓位信息结构体
     * @param margin 用户存入的保证金数量（USDC）
     * @param borrowed 用户借入的资金数量（USDC）
     * @param position 仓位大小（虚拟 ETH 数量）
     *                 正数表示多头仓位（持有虚拟 ETH）
     *                 负数表示空头仓位（借入虚拟 ETH）
     */
    struct PositionInfo {
        uint256 margin;      // 保证金
        uint256 borrowed;    // 借入金额
        int256 position;     // 仓位（正数=多头，负数=空头）
    }

    /// @notice 用户地址到仓位信息的映射
    /// @dev 每个用户同时只能持有一个仓位
    mapping(address => PositionInfo) public positions;

    /**
     * @notice 构造函数，初始化虚拟 AMM 池
     * @param _usdc USDC 代币合约地址
     * @param vEth 初始虚拟 ETH 储备量
     * @param vUSDC 初始虚拟 USDC 储备量
     */
    constructor(IERC20 _usdc, uint256 vEth, uint256 vUSDC) {
        require(address(_usdc) != address(0), "USDC zero");
        require(vEth > 0 && vUSDC > 0, "Invalid reserves");
        USDC = _usdc;
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;  // 计算并固定恒定乘积 K
    }

    /**
     * @notice 开设杠杆仓位
     * @dev 用户存入保证金，根据杠杆倍数计算名义价值，并在虚拟 AMM 中开仓
     * @param _margin 保证金数量（USDC）
     * @param level 杠杆倍数（例如：5 表示 5 倍杠杆）
     * @param long 是否做多（true=多头，false=空头）
     *
     * 流程说明：
     * 1. 验证用户当前没有持仓
     * 2. 从用户账户转入保证金
     * 3. 计算名义价值 = 保证金 × 杠杆倍数
     * 4. 如果做多：在 vAMM 中买入虚拟 ETH
     *    如果做空：在 vAMM 中卖出虚拟 ETH
     */
    function openPosition(uint256 _margin, uint256 level, bool long) external {
        require(_margin > 0, "Margin zero");
        require(level >= 1, "Level too low");

        PositionInfo storage pos = positions[msg.sender];
        require(pos.position == 0, "Position already open");

        // 从用户转入保证金
        USDC.transferFrom(msg.sender, address(this), _margin);

        // 计算名义价值（保证金 × 杠杆倍数）
        // 注：Solidity 0.8.x 自动检测溢出，无需手动验证
        uint256 notional = _margin * level;

        pos.margin = _margin;
        pos.borrowed = notional - _margin;  // 借入金额 = 名义价值 - 保证金

        if (long) {
            // 做多：用 USDC 买入虚拟 ETH
            uint256 ethSize = _virtualBuy(notional);
            pos.position = int256(ethSize);  // 正数表示持有 ETH
        } else {
            // 做空：卖出虚拟 ETH 获得 USDC
            uint256 ethSize = _virtualSell(notional);
            pos.position = -int256(ethSize);  // 负数表示借入 ETH
        }
    }

    /**
     * @notice 平仓并结算盈亏
     * @dev 计算盈亏，关闭虚拟仓位，返还保证金及盈利（如有）
     *
     * 流程说明：
     * 1. 验证用户有持仓
     * 2. 计算当前盈亏
     * 3. 在 vAMM 中平仓
     * 4. 结算：保证金 + 盈利 或 保证金 - 亏损
     * 5. 将结算金额转回用户
     */
    function closePosition() external {
        PositionInfo memory pos = positions[msg.sender];
        require(pos.position != 0, "No open position");

        // 计算盈亏
        int256 pnl = calculatePnL(msg.sender);

        // 在虚拟池中平仓
        _closeVirtual(pos);

        // 删除仓位记录
        delete positions[msg.sender];

        // 计算结算金额并转账
        uint256 settlement = _settlementAmount(pos, pnl);
        if (settlement > 0) {
            USDC.transfer(msg.sender, settlement);
        }
    }

    /**
     * @notice 清算用户仓位
     * @dev 当用户亏损超过保证金的 80% 时，第三方可执行清算并获得剩余保证金奖励
     * @param _user 待清算的用户地址
     *
     * 清算条件：
     * 1. 仓位存在亏损（pnl < 0）
     * 2. 亏损金额 ≥ 保证金 × 80%
     *
     * 清算奖励：
     * - 清算者获得剩余保证金（保证金 - 亏损）
     */
    function liquidatePosition(address _user) external {
        require(msg.sender != _user, "Self liquidation");

        PositionInfo memory pos = positions[_user];
        require(pos.position != 0, "No open position");

        // 计算盈亏
        int256 pnl = calculatePnL(_user);
        require(pnl < 0, "Position solvent");

        // 检查是否达到清算阈值
        uint256 loss = uint256(-pnl);
        require(loss * 100 >= pos.margin * LIQUIDATION_THRESHOLD, "Loss too small");

        // 在虚拟池中平仓
        _closeVirtual(pos);

        // 删除仓位记录
        delete positions[_user];

        // 将剩余保证金作为奖励转给清算者
        uint256 reward = _settlementAmount(pos, pnl);
        if (reward > 0) {
            USDC.transfer(msg.sender, reward);
        }
    }

    /**
     * @notice 计算用户仓位的盈亏
     * @dev 根据当前虚拟池价格计算如果平仓的盈亏情况
     * @param user 用户地址
     * @return pnl 盈亏金额（正数=盈利，负数=亏损）
     *
     * 计算原理：
     * - 多头：假设卖出持有的虚拟 ETH，计算获得的 USDC 与名义价值的差额
     * - 空头：假设买回借入的虚拟 ETH，计算花费的 USDC 与名义价值的差额
     */
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory pos = positions[user];
        if (pos.position == 0) {
            return 0;
        }

        // 名义价值 = 保证金 + 借入金额
        uint256 notional = pos.margin + pos.borrowed;

        if (pos.position > 0) {
            // 多头仓位：计算卖出 ETH 能获得多少 USDC
            uint256 ethSize = uint256(pos.position);

            // 模拟将 ETH 卖回池子
            uint256 newETH = vETHAmount + ethSize;
            uint256 newUSDC = vK / newETH;
            if (vK % newETH != 0) {
                newUSDC += 1;
            }
            uint256 usdcOut = vUSDCAmount - newUSDC;  // 获得的 USDC

            // 盈亏 = 获得的 USDC - 名义价值
            if (usdcOut >= notional) {
                return int256(usdcOut - notional);
            } else {
                return -int256(notional - usdcOut);
            }
        } else {
            // 空头仓位：计算买回 ETH 需要花费多少 USDC
            uint256 ethSize = uint256(-pos.position);

            // 检查是否超过池子容量
            if (ethSize >= vETHAmount) {
                return -int256(notional);  // 完全亏损
            }

            // 模拟从池子买回 ETH
            uint256 newETH = vETHAmount - ethSize;
            uint256 newUSDC = vK / newETH;
            if (vK % newETH != 0) {
                newUSDC += 1;
            }
            uint256 usdcIn = newUSDC - vUSDCAmount;  // 需要支付的 USDC

            // 盈亏 = 名义价值 - 需要支付的 USDC
            if (notional >= usdcIn) {
                return int256(notional - usdcIn);
            } else {
                return -int256(usdcIn - notional);
            }
        }
    }

    /**
     * @notice 虚拟买入（用 USDC 买 ETH）
     * @dev 根据恒定乘积公式计算可获得的 ETH 数量，并更新虚拟储备
     * @param usdcIn 投入的 USDC 数量
     * @return ethOut 获得的 ETH 数量
     *
     * 公式：vK = vETHAmount * vUSDCAmount
     * - newUSDC = vUSDCAmount + usdcIn
     * - newETH = vK / newUSDC（向上取整以保护池子）
     * - ethOut = vETHAmount - newETH
     *
     * 注意：除法向上取整，防止因截断导致 K 值减小
     */
    function _virtualBuy(uint256 usdcIn) internal returns (uint256 ethOut) {
        require(usdcIn > 0, "Input zero");

        uint256 newUSDC = vUSDCAmount + usdcIn;
        uint256 newETH = vK / newUSDC;

        // 向上取整以保护恒定乘积不变量
        if (vK % newUSDC != 0) {
            newETH += 1;
        }

        require(newETH < vETHAmount, "Trade too small");

        ethOut = vETHAmount - newETH;

        // 更新虚拟储备
        vETHAmount = newETH;
        vUSDCAmount = newUSDC;
    }

    /**
     * @notice 虚拟卖出（卖 ETH 换 USDC）
     * @dev 根据恒定乘积公式计算需要投入的 ETH 数量，并更新虚拟储备
     * @param usdcOut 期望获得的 USDC 数量
     * @return ethIn 需要投入的 ETH 数量
     *
     * 公式：vK = vETHAmount * vUSDCAmount
     * - newUSDC = vUSDCAmount - usdcOut
     * - newETH = vK / newUSDC（向上取整以保护池子）
     * - ethIn = newETH - vETHAmount
     *
     * 注意：除法向上取整，防止因截断导致 K 值减小
     */
    function _virtualSell(uint256 usdcOut) internal returns (uint256 ethIn) {
        require(usdcOut > 0, "Output zero");
        require(usdcOut < vUSDCAmount, "Insufficient vUSDC");

        uint256 newUSDC = vUSDCAmount - usdcOut;
        uint256 newETH = vK / newUSDC;

        // 向上取整以保护恒定乘积不变量
        if (vK % newUSDC != 0) {
            newETH += 1;
        }

        require(newETH > vETHAmount, "Trade too small");

        ethIn = newETH - vETHAmount;

        // 更新虚拟储备
        vETHAmount = newETH;
        vUSDCAmount = newUSDC;
    }

    /**
     * @notice 在虚拟池中平仓
     * @dev 根据仓位方向，将持仓归还给虚拟池
     * @param pos 仓位信息
     *
     * - 多头：将持有的虚拟 ETH 归还池子
     * - 空头：将借入的虚拟 ETH 归还池子
     *
     * 注意：除法向上取整，防止因截断导致 K 值减小
     */
    function _closeVirtual(PositionInfo memory pos) internal {
        if (pos.position > 0) {
            // 多头平仓：归还 ETH
            uint256 ethSize = uint256(pos.position);
            uint256 newETH = vETHAmount + ethSize;
            uint256 newUSDC = vK / newETH;

            // 向上取整以保护恒定乘积不变量
            if (vK % newETH != 0) {
                newUSDC += 1;
            }

            vETHAmount = newETH;
            vUSDCAmount = newUSDC;
        } else {
            // 空头平仓：归还 ETH
            uint256 ethSize = uint256(-pos.position);
            require(ethSize < vETHAmount, "Too much size");

            uint256 newETH = vETHAmount - ethSize;
            uint256 newUSDC = vK / newETH;

            // 向上取整以保护恒定乘积不变量
            if (vK % newETH != 0) {
                newUSDC += 1;
            }

            vETHAmount = newETH;
            vUSDCAmount = newUSDC;
        }
    }

    /**
     * @notice 计算结算金额
     * @dev 根据盈亏计算最终返还给用户的 USDC 数量
     * @param pos 仓位信息
     * @param pnl 盈亏金额
     * @return 结算金额（保证金 ± 盈亏）
     *
     * 计算逻辑：
     * - 盈利：返还 保证金 + 盈利
     * - 亏损：返还 保证金 - 亏损（最低为 0）
     */
    function _settlementAmount(PositionInfo memory pos, int256 pnl) internal pure returns (uint256) {
        if (pnl >= 0) {
            // 盈利情况
            return pos.margin + uint256(pnl);
        }

        // 亏损情况
        uint256 loss = uint256(-pnl);
        if (loss >= pos.margin) {
            // 亏损超过保证金，返回 0
            return 0;
        }

        // 返回剩余保证金
        return pos.margin - loss;
    }
}
