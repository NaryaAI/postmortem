// SPDX-License-Identifier: GPL3.0-or-later

interface IBaseV1Pair {
    function totalSupply() external view returns (uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function reserve0() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function current(address, uint256) external view returns (uint256);

    function burn(address) external returns (uint256, uint256);

    function getAmountOut(uint256, address) external view returns (uint256);

    function sync() external;

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}
