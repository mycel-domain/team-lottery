// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint wad) external;

    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    error WETH_ETHTransferFailed();
    error WETH_InvalidSignature();
    error WETH_ExpiredSignature();
    error WETH_InvalidTransferRecipient();

    // ERC20
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address guy) external view returns (uint);

    function allowance(address src, address dst) external view returns (uint);

    function approve(address spender, uint wad) external returns (bool);

    function transfer(address dst, uint wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint wad
    ) external returns (bool);

    event Approval(address indexed src, address indexed dst, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    // ERC-165
    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    // ERC-2612
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    // Permit2
    function permit2(
        address owner,
        address spender,
        uint amount,
        uint deadline,
        bytes calldata signature
    ) external;
}
