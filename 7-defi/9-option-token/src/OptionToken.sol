// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title OptionToken
 * @notice Simple European call option token backed by locked ETH collateral.
 *         The project owner mints tokens by depositing ETH. Holders can
 *         exercise on expiry day by paying the strike asset and receiving ETH.
 *         After the exercise window, the owner can reclaim any leftover ETH and
 *         mark the contract as expired.
 */
contract OptionToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice ERC20 token used to pay the strike (for example USDC).
    IERC20 public immutable strikeAsset;

    /// @notice Strike price denominated in strikeAsset with 18 decimals.
    uint256 public immutable strikePrice;

    /// @notice UNIX timestamp when the option can be exercised.
    uint64 public immutable expiry;

    /// @notice Seconds after expiry where exercise stays open.
    uint64 public immutable exerciseWindow;

    /// @notice Marks that the option has been fully settled and is inactive.
    bool public expired;

    /// @notice Total amount of option tokens exercised so far.
    uint256 public totalExercised;

    /// @notice Total strike asset collected during exercises.
    uint256 public totalStrikeCollected;

    event Minted(address indexed to, uint256 amount, uint256 collateralAdded);
    event LiquiditySeeded(address indexed pool, uint256 optionAmount, uint256 strikeAmount);
    event Exercised(address indexed account, address indexed receiver, uint256 amount, uint256 strikePaid);
    event CollateralReclaimed(address indexed owner, address indexed receiver, uint256 amount);
    event StrikeWithdrawn(address indexed owner, address indexed receiver, uint256 amount);

    error Expired();
    error ExerciseWindowClosed();
    error ExerciseWindowNotOpened();
    error InvalidReceiver();
    error InvalidStrikePrice();
    error InvalidAmount();
    error MintAmountZero();
    error NotExpired();

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        IERC20 strikeAsset_,
        uint256 strikePrice_,
        uint64 expiry_,
        uint64 exerciseWindow_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        if (expiry_ <= block.timestamp) {
            revert Expired();
        }
        if (address(strikeAsset_) == address(0)) {
            revert InvalidReceiver();
        }
        if (strikePrice_ == 0) {
            revert InvalidStrikePrice();
        }
        if (exerciseWindow_ == 0) {
            revert ExerciseWindowClosed();
        }

        strikeAsset = strikeAsset_;
        strikePrice = strikePrice_;
        expiry = expiry_;
        exerciseWindow = exerciseWindow_;
    }

    receive() external payable {
        revert MintAmountZero();
    }

    /**
     * @notice Project owner mints option tokens by depositing ETH collateral.
     * @dev Assumes the buyer already paid the option premium to the project owner via a separate workflow (for example an escrow or marketplace contract).
     * @param to Recipient that will receive the freshly minted option tokens.
     */
    function mintOptions(address to) external payable onlyOwner returns (uint256 minted) {
        if (block.timestamp >= expiry) {
            revert Expired();
        }
        if (msg.value == 0) {
            revert MintAmountZero();
        }
        if (to == address(0)) {
            revert InvalidReceiver();
        }

        minted = msg.value;
        _mint(to, minted);

        emit Minted(to, minted, msg.value);
    }

    /**
     * @notice Exercise option tokens during the exercise window.
     * @param amount Amount of option tokens to burn.
     * @param receiver Address that will receive the underlying ETH collateral.
     */
    function exercise(uint256 amount, address receiver) external returns (uint256 strikeCost) {
        if (block.timestamp < expiry) {
            revert ExerciseWindowNotOpened();
        }
        if (block.timestamp > expiry + exerciseWindow) {
            revert ExerciseWindowClosed();
        }
        if (expired) {
            revert Expired();
        }
        if (amount == 0) {
            revert MintAmountZero();
        }
        if (receiver == address(0)) {
            revert InvalidReceiver();
        }

        _burn(msg.sender, amount);

        strikeCost = Math.mulDiv(amount, strikePrice, 1e18);
        totalExercised += amount;
        totalStrikeCollected += strikeCost;

        strikeAsset.safeTransferFrom(msg.sender, address(this), strikeCost);

        (bool success,) = receiver.call{value: amount}("");
        if (!success) {
            revert InvalidReceiver();
        }

        emit Exercised(msg.sender, receiver, amount, strikeCost);
    }

    /**
     * @notice Owner withdraws strike asset received from exercises.
     * @param to Receiver of strike tokens.
     * @param amount Amount of strike tokens to withdraw.
     */
    function withdrawStrike(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) {
            revert InvalidReceiver();
        }
        strikeAsset.safeTransfer(to, amount);
        emit StrikeWithdrawn(msg.sender, to, amount);
    }

    /**
     * @notice Owner seeds liquidity by pairing option tokens with strike asset at a quoted premium.
     * @param pool Destination that will receive both assets (for example an AMM pool or treasury).
     * @param optionAmount Amount of option tokens to transfer.
     * @param strikeAmount Amount of strike tokens to transfer.
     */
    function seedLiquidity(address pool, uint256 optionAmount, uint256 strikeAmount) external onlyOwner {
        if (expired || block.timestamp >= expiry) {
            revert Expired();
        }
        if (pool == address(0)) {
            revert InvalidReceiver();
        }
        if (optionAmount == 0 || strikeAmount == 0) {
            revert InvalidAmount();
        }

        _transfer(msg.sender, pool, optionAmount);
        strikeAsset.safeTransferFrom(msg.sender, pool, strikeAmount);

        emit LiquiditySeeded(pool, optionAmount, strikeAmount);
    }

    /**
     * @notice Owner reclaims the remaining ETH collateral after the window closes.
     * Automatically marks the contract as expired to stop token transfers.
     * @param to Address that receives the remaining ETH.
     */
    function reclaimExpiredCollateral(address to) external onlyOwner returns (uint256 amount) {
        if (block.timestamp <= expiry + exerciseWindow) {
            revert NotExpired();
        }
        if (to == address(0)) {
            revert InvalidReceiver();
        }
        if (expired) {
            revert Expired();
        }
        expired = true;

        amount = address(this).balance;

        (bool success,) = to.call{value: amount}("");
        if (!success) {
            revert InvalidReceiver();
        }

        emit CollateralReclaimed(msg.sender, to, amount);
    }

    /**
     * @notice Owner can burn expired option tokens from a holder after settlement.
     * @dev Helps tidy up supply once the contract is expired.
     */
    function burnExpired(address holder, uint256 amount) external onlyOwner {
        if (!expired) {
            revert NotExpired();
        }
        _burn(holder, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20) {
        if (expired && from != address(0) && to != address(0)) {
            revert Expired();
        }
        super._update(from, to, value);
    }
}
