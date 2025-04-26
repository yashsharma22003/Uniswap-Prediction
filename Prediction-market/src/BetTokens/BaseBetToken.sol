// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // Use a recent compatible version

// Import the standard ERC20 contract from OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Optional: Import Ownable or AccessControl for more robust permissioning if needed later
// import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EnhancedBetToken
 * @dev ERC20 token based on BaseBetToken logic, inheriting from OpenZeppelin.
 * Features:
 * - Standard ERC20 functions and events via inheritance.
 * - Fixed maximum supply (MAX_SUPPLY).
 * - A designated 'minter' address.
 * - Minting and Burning restricted to the 'minter' address.
 */
contract BaseBetToken is ERC20 {
    // --- State Variables ---

    // Maximum total supply cap (immutable means it's set once in constructor)
    uint256 public immutable MAX_SUPPLY;

    // The address designated as the minter/burner
    address public minter;

    // --- Events ---
    // ERC20 Transfer and Approval events are inherited from ERC20.sol

    // --- Modifiers ---

    /**
     * @dev Throws if called by any account other than the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "EnhancedBetToken: Caller is not the minter");
        _;
    }

    // --- Constructor ---

    /**
     * @dev Sets the token name, symbol, max supply, and the minter address.
     * Initializes the ERC20 part of the contract.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param maxSupply_ The maximum possible total supply.
     * @param minterAddress_ The address allowed to mint and burn tokens.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address minterAddress_
    ) ERC20(name_, symbol_) { // Call the ERC20 constructor
        require(minterAddress_ != address(0), "EnhancedBetToken: Minter cannot be zero address");
        require(maxSupply_ > 0, "EnhancedBetToken: Max supply must be greater than zero");

        MAX_SUPPLY = maxSupply_;
        minter = minterAddress_;
        // Note: Decimals defaults to 18 in OpenZeppelin's ERC20,
        // which matches the original contract's assumption.
        // No need to explicitly set decimals unless you override the _decimals() function.
    }

    // --- Minter Functions ---

    /**
     * @dev Creates `amount` tokens and assigns them to `to`, increasing
     * the total supply. Restricted to the minter.
     * Emits a {Transfer} event with `from` set to the zero address.
     * Requirements:
     * - `to` cannot be the zero address. (Handled by _mint)
     * - The total supply after minting must not exceed `MAX_SUPPLY`.
     * - Caller must be the `minter`.
     */
    function mint(address to, uint256 amount) public virtual onlyMinter {
        require(totalSupply() + amount <= MAX_SUPPLY, "EnhancedBetToken: Mint amount exceeds max supply");
        _mint(to, amount); // Use OpenZeppelin's internal _mint function
                           // It handles balance updates, total supply updates, and emits the Transfer event.
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply. Restricted to the minter.
     * This allows the minter to burn tokens from any account.
     * Emits a {Transfer} event with `to` set to the zero address.
     * Requirements:
     * - `account` cannot be the zero address. (Handled by _burn)
     * - `account` must have at least `amount` tokens. (Handled by _burn)
     * - Caller must be the `minter`.
     */
    function burnFrom(address account, uint256 amount) public virtual onlyMinter {
         // Use OpenZeppelin's internal _burn function
         // It handles balance checks, balance updates, total supply updates,
         // and emits the Transfer event.
        _burn(account, amount);
    }

    // --- Overrides (Optional) ---

    // You could override _update or other internal functions if needed,
    // but for this use case, _mint and _burn are sufficient.

    // --- Standard ERC20 functions ---
    // name(), symbol(), decimals(), totalSupply(), balanceOf(), transfer(),
    // allowance(), approve(), transferFrom() are all inherited from ERC20.sol
    // and work as standard.
}