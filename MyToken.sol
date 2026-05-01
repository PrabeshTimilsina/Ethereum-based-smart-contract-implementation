// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    //Initilizing the token name and symbol and setting the contract owner with ownable
    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
        
    }

 
 //Owner can mint token to any address, only the owner have this functionality
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

//token transfer can be paused or unpaused by owner
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
 
 // Multiple inheritance so overriding _update method and specifing which parent's _update function to implement
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}