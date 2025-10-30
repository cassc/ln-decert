// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {MemeToken} from "./MemeToken.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

/// @title MemeFactory 合约
/// @notice 负责克隆 MemeToken 实例，并处理用户支付与流动性添加逻辑。
contract MemeFactory is ReentrancyGuard {
    using Clones for address;
    using SafeERC20 for IERC20;

    struct MemeInfo {
        address issuer;
        uint256 price;
        uint256 perMint;
        bool liquidityAdded;
    }

    address public immutable implementation;
    address payable public immutable projectTreasury;
    IUniswapV2Router02 public immutable router;

    mapping(address => MemeInfo) public memeInfo;
    mapping(address => uint256) public pendingLiquidityTokens;

    event MemeDeployed(
        address indexed token,
        address indexed issuer,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    event MemeMinted(address indexed token, address indexed buyer, uint256 amount, uint256 pricePaid);
    event LiquidityAdded(address indexed token, uint256 amountToken, uint256 amountEth);

    error InvalidConfig();
    error MemeNotFound();
    error IncorrectPayment();
    error ZeroValue();
    error PriceNotBetter();

    constructor(address projectTreasury_, address router_) {
        if (projectTreasury_ == address(0) || router_ == address(0)) revert InvalidConfig();
        projectTreasury = payable(projectTreasury_);
        implementation = address(new MemeToken());
        router = IUniswapV2Router02(router_);
    }

    function deployMeme(
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address token) {
        if (bytes(symbol).length == 0) revert InvalidConfig();
        if (totalSupply == 0 || perMint == 0 || perMint > totalSupply || price == 0) revert InvalidConfig();

        // 使用 EIP-1167 最小代理模式克隆 MemeToken 实现
        token = implementation.clone();
        MemeToken(token).initialize(symbol, msg.sender, totalSupply, perMint, price);

        memeInfo[token] = MemeInfo({issuer: msg.sender, price: price, perMint: perMint, liquidityAdded: false});

        emit MemeDeployed(token, msg.sender, symbol, totalSupply, perMint, price);
    }

    /// @notice 买家按设定价格铸造 Meme，并自动抽取 5% 资金与代币去做市。
    function mintMeme(address tokenAddr) external payable nonReentrant {
        MemeInfo memory info = memeInfo[tokenAddr];
        if (info.issuer == address(0)) revert MemeNotFound();
        if (msg.value != info.price) revert IncorrectPayment();

        MemeToken token = MemeToken(tokenAddr);
        // 将代币铸造到工厂地址，然后分配给买家和流动性池
        uint256 minted = token.mint(address(this));
        emit MemeMinted(tokenAddr, msg.sender, minted, msg.value);

        // 计算 5% 的 ETH 用于添加流动性，其余 ETH 发送给发行方
        uint256 liquidityEth = msg.value / 20;
        uint256 issuerPayout = msg.value - liquidityEth;

        // 预留 5% 的代币用于和 ETH 一起添加流动性
        uint256 additionalTokens = (minted * 5) / 100;
        pendingLiquidityTokens[tokenAddr] += additionalTokens;

        // 剩余 95% 的代币立即发送给买家
        uint256 buyerTokens = minted - additionalTokens;
        if (buyerTokens > 0) {
            token.transfer(msg.sender, buyerTokens);
        }

        if (liquidityEth > 0 && pendingLiquidityTokens[tokenAddr] > 0) {
            uint256 tokenAmountForLiquidity = pendingLiquidityTokens[tokenAddr];

            // 授权路由器使用添加流动性所需的代币
            IERC20(tokenAddr).forceApprove(address(router), tokenAmountForLiquidity);

            // 首次添加流动性时严格使用铸造价格，后续允许设置最低值为 0 以避免滑点限制
            uint256 amountTokenMin = info.liquidityAdded ? 0 : tokenAmountForLiquidity;
            uint256 amountEthMin = info.liquidityAdded ? 0 : liquidityEth;

            (uint256 amountTokenUsed, uint256 amountEthUsed, ) = router.addLiquidityETH{value: liquidityEth}(
                tokenAddr,
                tokenAmountForLiquidity,
                amountTokenMin,
                amountEthMin,
                projectTreasury,
                block.timestamp + 15 minutes
            );

            if (!info.liquidityAdded) {
                memeInfo[tokenAddr].liquidityAdded = true;
            }

            // 更新剩余待添加流动性的代币数量，避免重复累计
            pendingLiquidityTokens[tokenAddr] = tokenAmountForLiquidity - amountTokenUsed;

            // 若路由器未用完全部 ETH，将多余部分退还给发行方
            if (amountEthUsed < liquidityEth) {
                uint256 refundEth = liquidityEth - amountEthUsed;
                issuerPayout += refundEth;
            }

            emit LiquidityAdded(tokenAddr, amountTokenUsed, amountEthUsed);
        } else if (liquidityEth > 0) {
            // 如果暂时无法添加流动性，则将 ETH 发送给发行方
            issuerPayout += liquidityEth;
        }

        if (issuerPayout > 0) {
            // 将应得的 ETH 发送给发行方
            (bool okIssuer, ) = info.issuer.call{value: issuerPayout}("");
            require(okIssuer, "issuer payout failed");
        }
    }

    /// @notice 当 Uniswap 价格优于首发价时，允许买家直接通过工厂买入。
    function buyMeme(address tokenAddr) external payable nonReentrant {
        if (msg.value == 0) revert ZeroValue();

        MemeInfo memory info = memeInfo[tokenAddr];
        if (info.issuer == address(0)) revert MemeNotFound();

        if (!info.liquidityAdded) revert PriceNotBetter();

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddr;

        uint256[] memory amountsOut = router.getAmountsOut(msg.value, path);
        uint256 amountOut = amountsOut[amountsOut.length - 1];
        uint256 baseline = (msg.value * info.perMint) / info.price;
        if (amountOut <= baseline) revert PriceNotBetter();

        uint256 minOut = baseline + 1;
        router.swapExactETHForTokens{value: msg.value}(
            minOut,
            path,
            msg.sender,
            block.timestamp + 15 minutes
        );
    }
}
