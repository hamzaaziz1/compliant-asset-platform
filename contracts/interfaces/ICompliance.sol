// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICompliance
 * @notice Answers "does this transfer break any rules?" and tracks state that
 *         rules depend on (e.g. current number of holders).
 *
 * Separating this from the identity registry is the key ERC-3643 design choice:
 * rules change often and independently of who is verified.
 */
interface ICompliance {
    /// @notice pure check — can `from` send `amount` to `to` under current rules?
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    /// @notice hook called after a successful transfer so compliance can update counters
    function transferred(address from, address to, uint256 amount) external;

    /// @notice hook called after a mint
    function created(address to, uint256 amount) external;

    /// @notice hook called after a burn
    function destroyed(address from, uint256 amount) external;
}
