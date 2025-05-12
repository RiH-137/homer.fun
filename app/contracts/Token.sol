// we are going with ERC20 for token contract

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    address public owner;

    // The constructor mints an initial supply of tokens to the deployer
    constructor(string memory name, string memory symbol, uint initialMintValue) ERC20(name, symbol) {
        _mint(msg.sender, initialMintValue);
        owner = msg.sender;
    }

    // function to mint new tokens, only callable by the owner
    function mint(uint mintQty, address receiver) external returns(uint){
        require(msg.sender == owner, "Mint can only be called by the owner");
        _mint(receiver, mintQty);
        return 1;
    }


}