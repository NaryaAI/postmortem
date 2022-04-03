pragma solidity 0.5.16;

import "./CTokenStorage.sol";
import "./interfaces/CTokenInterface.sol";

contract CToken is CTokenStorage, CTokenInterface {
	function getCash() external view returns (uint);
}