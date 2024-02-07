// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Vault} from "./Vault.sol";

contract VaultFactory {
    Vault[] public allVaults;

    event NewFactoryVault(Vault indexed vault, VaultFactory indexed vaultFactory);

    function createVault() external returns (address) {
        return address(new Vault());
    }

    function totalVaults() external view returns (uint256) {
        return allVaults.length;
    }
}
