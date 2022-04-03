pragma solidity ^0.5.16;

import "./interfaces/ComptrollerInterface.sol";

contract Comptroller is ComptrollerInterface {
	function getAccountLiquidity(address account) public view returns (uint, uint, uint); 
}