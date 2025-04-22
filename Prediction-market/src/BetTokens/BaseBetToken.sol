// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BaseBetToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18; // Assuming 18 decimals for simplicity

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    uint256 public immutable MAX_SUPPLY;

    address public minter; // The CryptoMarketPool contract address

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, address _minter) {
        require(_minter != address(0), "Minter cannot be zero address");
        name = _name;
        symbol = _symbol;
        MAX_SUPPLY = _maxSupply;
        minter = _minter;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Not the minter");
        _;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(_totalSupply + amount <= MAX_SUPPLY, "Max supply reached");
        _totalSupply += amount;
        _balances[to] += amount;
        // ERC20 Transfer event Transfer(address(0), to, amount) is good practice
    }

    function burn(address account, uint256 amount) external onlyMinter {
        require(_balances[account] >= amount, "Insufficient balance");
        _balances[account] -= amount;
        _totalSupply -= amount;
        // ERC20 Transfer event Transfer(account, address(0), amount) is good practice
    }
    // Add transfer/approve/transferFrom if tokens should be tradable
}