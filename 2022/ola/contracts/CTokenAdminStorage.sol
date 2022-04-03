pragma solidity 0.5.16;

import "./interfaces/ComptrollerInterface.sol";

/**
 * OLA_ADDITIONS : This base admin storage.
 */
contract CTokenAdminStorage {
    /**
     * @notice Administrator for this contract
     */
    address payable public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address payable public pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    ComptrollerInterface public comptroller;

    /**
     * @notice Implementation address for this contract
     */
    address public implementation;

    // OLA_ADDITIONS : Contract hash name
    bytes32 public contractNameHash;
}