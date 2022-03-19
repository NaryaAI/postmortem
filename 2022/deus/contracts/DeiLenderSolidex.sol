// Be name Khoda
// Bime Abolfazl
// SPDX-License-Identifier: GPL3.0-or-later

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ==================== DEI Lender Solidex ===================
// ==========================================================
// DEUS Finance: https://github.com/deusfinance

// Primary Author(s)
// MRM: https://github.com/smrm-dev
// MMD: https://github.com/mmd-mostafaee

// Reviewer(s)
// Vahid: https://github.com/vahid-dev
// HHZ: https://github.com/hedzed

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./interfaces/IMintHelper.sol";
import "./@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "./@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "./@boringcrypto/boring-solidity/contracts/ERC20.sol";
import "./@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol";
import "./@boringcrypto/boring-solidity/contracts/interfaces/IMasterContract.sol";
import "./@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";
import "./@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import {SolidexHolder as Holder} from "./SolidexHolder.sol";

interface LpDepositor {
    function getReward(address[] calldata pools) external;
}

interface HIERC20 {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

interface IOracle {
    function getPrice() external view returns (uint256);
}

contract DeiLenderSolidex is BoringOwnable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;
    using BoringERC20 for IERC20;

    event UpdateAccrue(uint256 interest);
    event Borrow(address from, address to, uint256 amount, uint256 debt);
    event Repay(address from, address to, uint256 amount, uint256 repayAmount);
    event AddCollateral(address from, address to, uint256 amount);
    event RemoveCollateral(address from, address to, uint256 amount);

    IERC20 public collateral;

    IERC20 public solid;
    IERC20 public solidex;
    address public lpDepositor;
    uint256 public maxCap;

    IOracle public oracle;

    uint256 public BORROW_OPENING_FEE;

    uint256 public LIQUIDATION_RATIO;

    uint256 public totalCollateral;
    Rebase public totalBorrow;

    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userBorrow;
    mapping(address => address) public userHolder;

    address public mintHelper;

    struct AccrueInfo {
        uint256 lastAccrued;
        uint256 feesEarned;
        uint256 interestPerSecond;
    }

    AccrueInfo public accrueInfo;

    constructor(
        IERC20 collateral_,
        IOracle oracle_,
        IERC20 solid_,
        IERC20 solidex_,
        address lpDepositor_,
        uint256 maxCap_,
        uint256 interestPerSecond_,
        uint256 borrowOpeningFee,
        uint256 liquidationRatio,
        address mintHelper_
    ) public {
        collateral = collateral_;
        accrueInfo.interestPerSecond = interestPerSecond_;
        accrueInfo.lastAccrued = block.timestamp;
        BORROW_OPENING_FEE = borrowOpeningFee;
        LIQUIDATION_RATIO = liquidationRatio;
        oracle = oracle_;
        solid = solid_;
        solidex = solidex_;
        lpDepositor = lpDepositor_;
        maxCap = maxCap_;
        mintHelper = mintHelper_;
    }

    function setOracle(IOracle oracle_) external onlyOwner {
        oracle = oracle_;
    }

    function setMaxCap(uint256 maxCap_) external onlyOwner {
        maxCap = maxCap_;
    }

    function setBorrowOpeningFee(uint256 borrowOpeningFee_) external onlyOwner {
        BORROW_OPENING_FEE = borrowOpeningFee_;
    }

    function setLiquidationRatio(uint256 liquidationRatio_) external onlyOwner {
        LIQUIDATION_RATIO = liquidationRatio_;
    }

    function setMintHelper(address mintHelper_) external onlyOwner {
        mintHelper = mintHelper_;
    }

    function getRepayAmount(uint256 amount)
        public
        view
        returns (uint256 repayAmount)
    {
        Rebase memory _totalBorrow = totalBorrow;
        (uint128 elastic, ) = getCurrentElastic();
        _totalBorrow.elastic = elastic;
        (_totalBorrow, repayAmount) = _totalBorrow.sub(amount, true);
    }

    /// returns user total debt (borrowed amount + interest)
    function getDebt(address user) public view returns (uint256 debt) {
        if (totalBorrow.base == 0) return 0;

        (uint128 elastic, ) = getCurrentElastic();
        return userBorrow[user].mul(uint256(elastic)) / totalBorrow.base;
    }

    /// returns liquidation price for requested user
    function getLiquidationPrice(address user) public view returns (uint256) {
        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return 0;

        uint256 liquidationPrice = (getDebt(user).mul(1e18).mul(1e18)) /
            (userCollateralAmount.mul(LIQUIDATION_RATIO));
        return liquidationPrice;
    }

    /// returns withdrawable amount for requested user
    function getWithdrawableCollateralAmount(address user)
        public
        view
        returns (uint256)
    {
        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return 0;

        uint256 neededCollateral = (getDebt(user).mul(1e18).mul(1e18)) /
            (oracle.getPrice().mul(LIQUIDATION_RATIO));

        return
            userCollateralAmount > neededCollateral
                ? userCollateralAmount - neededCollateral
                : 0;
    }

    function isSolvent(address user) public view returns (bool) {
        // accrue must have already been called!

        uint256 userCollateralAmount = userCollateral[user];
        if (userCollateralAmount == 0) return getDebt(user) == 0;

        return
            userCollateralAmount.mul(oracle.getPrice()).mul(LIQUIDATION_RATIO) /
                (uint256(1e18).mul(1e18)) >
            getDebt(user);
    }

    function getCurrentElastic()
        internal
        view
        returns (uint128 elastic, uint128 interest)
    {
        Rebase memory _totalBorrow = totalBorrow;
        uint256 elapsedTime = block.timestamp - accrueInfo.lastAccrued;
        if (elapsedTime != 0 && _totalBorrow.base != 0) {
            interest = (uint256(_totalBorrow.elastic)
                .mul(accrueInfo.interestPerSecond)
                .mul(elapsedTime) / 1e18).to128();
            elastic = _totalBorrow.elastic.add(interest);
        } else {
            return (totalBorrow.elastic, 0);
        }
    }

    function accrue() public {
        uint256 elapsedTime = block.timestamp - accrueInfo.lastAccrued;
        if (elapsedTime == 0) return;
        if (totalBorrow.base == 0) {
            accrueInfo.lastAccrued = uint256(block.timestamp);
            return;
        }

        (uint128 elastic, uint128 interest) = getCurrentElastic();

        accrueInfo.lastAccrued = uint256(block.timestamp);
        totalBorrow.elastic = elastic;
        accrueInfo.feesEarned = accrueInfo.feesEarned.add(interest);

        emit UpdateAccrue(interest);
    }

    function addCollateral(address to, uint256 amount) public {
        userCollateral[to] = userCollateral[to].add(amount);
        totalCollateral = totalCollateral.add(amount);
        if (userHolder[to] == address(0)) {
            Holder holder = new Holder(lpDepositor, address(this), to);
            userHolder[to] = address(holder);
        }
        collateral.safeTransferFrom(msg.sender, userHolder[to], amount);
        emit AddCollateral(msg.sender, to, amount);
    }

    function removeCollateral(address to, uint256 amount) public {
        accrue();
        userCollateral[msg.sender] = userCollateral[msg.sender].sub(amount);

        totalCollateral = totalCollateral.sub(amount);

        Holder(userHolder[msg.sender]).withdrawERC20(
            address(collateral),
            to,
            amount
        );

        require(isSolvent(msg.sender), "User is not solvent!");
        emit RemoveCollateral(msg.sender, to, amount);
    }

    function borrow(address to, uint256 amount) public returns (uint256 debt) {
        accrue();
        uint256 fee = amount.mul(BORROW_OPENING_FEE) / 1e18;
        (totalBorrow, debt) = totalBorrow.add(amount.add(fee), true);
        accrueInfo.feesEarned = accrueInfo.feesEarned.add(fee);
        userBorrow[msg.sender] = userBorrow[msg.sender].add(debt);

        require(
            totalBorrow.elastic <= maxCap,
            "Lender total borrow exceeds cap"
        );
        require(isSolvent(msg.sender), "User is not solvent!");
        IMintHelper(mintHelper).mint(to, amount);
        emit Borrow(msg.sender, to, amount.add(fee), debt);
    }

    function repayElastic(address to, uint256 debt)
        public
        returns (uint256 repayAmount)
    {
        accrue();

        uint256 amount = debt.mul(totalBorrow.base) / totalBorrow.elastic;

        (totalBorrow, repayAmount) = totalBorrow.sub(amount, true);
        userBorrow[to] = userBorrow[to].sub(amount);

        IMintHelper(mintHelper).burnFrom(msg.sender, repayAmount);

        emit Repay(msg.sender, to, amount, repayAmount);
    }

    function repayBase(address to, uint256 amount)
        public
        returns (uint256 repayAmount)
    {
        accrue();

        (totalBorrow, repayAmount) = totalBorrow.sub(amount, true);
        userBorrow[to] = userBorrow[to].sub(amount);

        IMintHelper(mintHelper).burnFrom(msg.sender, repayAmount);

        emit Repay(msg.sender, to, amount, repayAmount);
    }

    function liquidate(address[] calldata users, address to) public {
        accrue();

        uint256 totalCollateralAmount;
        uint256 totalDeiAmount;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            if (!isSolvent(user)) {
                uint256 amount = userBorrow[user];

                uint256 deiAmount;
                (totalBorrow, deiAmount) = totalBorrow.sub(amount, true);

                totalDeiAmount += deiAmount;
                totalCollateralAmount += userCollateral[user];

                emit RemoveCollateral(user, to, userCollateral[user]);
                emit Repay(msg.sender, user, amount, deiAmount);

                Holder(userHolder[user]).withdrawERC20(
                    address(collateral),
                    to,
                    userCollateral[user]
                );
                userCollateral[user] = 0;
                userBorrow[user] = 0;
            }
        }

        require(totalDeiAmount != 0, "All users are solvent");

        IMintHelper(mintHelper).burnFrom(msg.sender, totalDeiAmount);
    }

    function withdrawFees(address to, uint256 amount) public onlyOwner {
        accrue();

        IMintHelper(mintHelper).mint(to, amount);
        accrueInfo.feesEarned = accrueInfo.feesEarned.sub(amount);
    }

    function claim(address[] calldata pools) public {
        Holder(userHolder[msg.sender]).claim(pools);
    }

    function claimAndWithdraw(address[] calldata pools, address to) public {
        Holder(userHolder[msg.sender]).claim(pools);
        Holder(userHolder[msg.sender]).withdrawERC20(
            address(solid),
            to,
            solid.balanceOf(userHolder[msg.sender])
        );
        Holder(userHolder[msg.sender]).withdrawERC20(
            address(solidex),
            to,
            solidex.balanceOf(userHolder[msg.sender])
        );
    }

    function emergencyHolderWithdraw(
        address holder,
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        Holder(holder).withdrawERC20(token, to, amount);
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        HIERC20(token).transfer(to, amount);
    }
}