// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // Match your project's version

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title HighBetToken
 * @dev An ERC20 token awarded for 'High' predictions in CryptoMarketPool.
 * Fixed maximum supply, minting controlled by an authorized minter.
 */
contract HighBetToken is ERC20, Ownable {
    // <<< SET YOUR DESIRED MAXIMUM SUPPLY FOR HIGH TOKENS >>>
    uint256 public constant MAX_SUPPLY = 500000000 * (10**18); // Example: 500 Million

    address public minter; // The CryptoMarketPool contract address

    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    constructor(address initialOwner) ERC20("HighBet Token", "HIGHBET") Ownable(initialOwner) {}

    function setMinter(address _newMinter) external onlyOwner {
        require(_newMinter != address(0), "HighBetToken: Minter cannot be the zero address");
        address oldMinter = minter;
        minter = _newMinter;
        emit MinterChanged(oldMinter, _newMinter);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "HighBetToken: Caller is not the authorized minter");
        require(totalSupply() + amount <= MAX_SUPPLY, "HighBetToken: Minting exceeds maximum supply");
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}