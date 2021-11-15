// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./interfaces/IDegisToken.sol";

/**@title  Degis Token
 * @notice DegisToken inherits from ERC20Votes which contains the ERC20 Permit.
 *         DegisToken can use the permit function rather than approve + transferFrom.
 *
 *         DegisToken has an owner, a minter and a burner.
 *         When lauched on mainnet, the owner may be removed or tranferred to a multisig.
 *         By default, the owner & minter account will be the one that deploys the contract.
 *         The minter may(and should) later be passed to InsurancePool.
 *         The burner may(and should) later be passed to EmergencyPool.
 */
contract DegisToken is ERC20Votes, IDegisToken {
    // Some manager addresses
    address public minter;
    address public burner;
    address public owner;

    uint256 public constant DEGIS_CAP = 10e8 ether;

    bool public ownerMintEnabled;

    /**
     * @notice Use ERC20 + ERC20Permit constructor and set the owner, minter and burner
     */
    constructor() ERC20("DegisToken", "DEGIS") ERC20Permit("DegisToken") {
        minter = msg.sender;
        owner = msg.sender;
        burner = msg.sender;

        // At the beginning, owner can mint tokens to the lock degis contract
        ownerMintEnabled = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this funciton");
        _;
    }

    modifier notExceedCap(uint256 _amount) {
        require(
            totalSupply() + _amount <= cap(),
            "DegisToken exceeds the cap (100 million)"
        );
        _;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public pure returns (uint256) {
        return DEGIS_CAP;
    }

    /**
     * @notice Owner will not be able to mint tokens, used when investor tokens are minted
     */
    function closeOwnerMint() public onlyOwner {
        ownerMintEnabled = false;
        emit CloseOwnerMint(owner, block.number);
    }

    /**
     * @notice Pass the minter role to a new address, only the owner can change the minter !!!
     * @param _newMinter: New minter's address
     * @return Whether the minter has been changed
     */
    function passMinterRole(address _newMinter)
        public
        onlyOwner
        returns (bool)
    {
        address oldMinter = minter; // Temporarily store the old minter address for event usage
        minter = _newMinter;

        emit MinterChanged(oldMinter, _newMinter);
        return true;
    }

    /**
     * @notice Pass the owner role to a new address, only the owner can change the owner !!!
     * @param _newOwner: New owner's address
     * @return Whether the owner has been changed
     */
    function passOwnership(address _newOwner) public onlyOwner returns (bool) {
        owner = _newOwner;

        emit OwnerChanged(msg.sender, _newOwner);
        return true;
    }

    /**
     * @notice Pass the owner role to a new address, only the owner can change the owner !!!
     * @param _newBurner: New burner's address
     * @return Whether the burner has been changed
     */
    function passBurnerRole(address _newBurner)
        public
        onlyOwner
        returns (bool)
    {
        address oldBurner = burner; // Temporarily store the old burner address for event usage
        burner = _newBurner;

        emit BurnerChanged(oldBurner, _newBurner);
        return true;
    }

    /**
     * @notice Release the ownership to zero address, can never get back !!!
     * @return Whether the ownership has been released
     */
    function releaseOwnership() public onlyOwner returns (bool) {
        owner = address(0);

        emit ReleaseOwnership(msg.sender);
        return true;
    }

    /**
     * @notice Mint tokens
     * @param _account: Receiver's address
     * @param _amount: Amount to be minted
     */
    function mint(address _account, uint256 _amount)
        public
        notExceedCap(_amount)
    {
        require(msg.sender == minter, "Only the minter can mint Degis Reward");

        _mint(_account, _amount); // ERC20 method with an event
    }

    /**
     * @notice Mint tokens by the owner
     * @param _account: Receiver's address (Should be the lockDegis contract)
     * @param _amount: Amount to be minted
     */
    function mintByOwner(address _account, uint256 _amount)
        public
        onlyOwner
        notExceedCap(_amount)
    {
        _mint(_account, _amount);

        emit MintByOwner(_account, _amount);
    }

    /**
     * @notice Burn tokens
     * @param _account: address
     * @param _amount: amount to be burned
     */
    function burn(address _account, uint256 _amount) public {
        require(msg.sender == burner, "Only the burner can call this function");
        _burn(_account, _amount);
    }
}
