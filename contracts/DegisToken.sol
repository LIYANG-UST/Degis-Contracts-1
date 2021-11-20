// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
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
contract DegisToken is ERC20Permit, IDegisToken {
    address public owner;

    address[] public minterList;
    mapping(address => bool) isMinter;

    address[] public burnerList;
    mapping(address => bool) isBurner;

    uint256 public constant DEGIS_CAP = 10e8 ether;

    bool public ownerMintEnabled; // Whether enable the owner to mint

    /**
     * @notice Use ERC20 + ERC20Permit constructor and set the owner, minter and burner
     */
    constructor() ERC20("DegisToken", "DEGIS") ERC20Permit("DegisToken") {
        owner = msg.sender;
        // At the beginning, owner can mint tokens to the lock degis contract
        ownerMintEnabled = true;
    }

    // Only the owner can call some functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this funciton");
        _;
    }

    // Degis toke has a hard cap of 100 million
    modifier notExceedCap(uint256 _amount) {
        require(
            totalSupply() + _amount <= cap(),
            "DegisToken exceeds the cap (100 million)"
        );
        _;
    }

    // Check if the msg.sender is in the minter list
    modifier inMinterList(address _sender) {
        require(
            isMinter[_sender] == true,
            "Only the address in the minter list can call this function"
        );
        _;
    }

    // Check if the msg.sender is in the burner list
    modifier inBurnerList(address _sender) {
        require(
            isBurner[_sender] == true,
            "Only the address in the minter list can call this function"
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
     * @notice Add a new minter into the list
     * @param _newMinter Address of the new minter
     */
    function addMinter(address _newMinter) public onlyOwner {
        require(
            isMinter[_newMinter] == false,
            "This address is already a minter"
        );
        minterList.push(_newMinter);

        emit MinterAdded(_newMinter);
    }

    /**
     * @notice Remove a minter from the list
     * @param _oldMinter Address of the minter to be removed
     */
    function removeMinter(address _oldMinter) public onlyOwner {
        require(isMinter[_oldMinter] == true, "This address is not a minter");

        uint256 length = minterList.length;
        for (uint256 i = 0; i < length; i++) {
            if (minterList[i] == _oldMinter) {
                for (uint256 j = i; j < length - 1; j++) {
                    minterList[j] = minterList[j + 1];
                }
                minterList.pop();
            } else continue;
        }

        emit MinterRemoved(_oldMinter);
    }

    /**
     * @notice Add a new burner into the list
     * @param _newBurner Address of the new burner
     */
    function addBurner(address _newBurner) public onlyOwner {
        require(
            isBurner[_newBurner] == false,
            "This address is already a burner"
        );
        burnerList.push(_newBurner);

        emit BurnerAdded(_newBurner);
    }

    /**
     * @notice Remove a minter from the list
     * @param _oldBurner Address of the minter to be removed
     */
    function removeBurner(address _oldBurner) public onlyOwner {
        require(isMinter[_oldBurner] == true, "This address is not a burner");

        uint256 length = burnerList.length;
        for (uint256 i = 0; i < length; i++) {
            if (burnerList[i] == _oldBurner) {
                for (uint256 j = i; j < length - 1; j++) {
                    burnerList[j] = burnerList[j + 1];
                }
                burnerList.pop();
            } else continue;
        }

        emit BurnerRemoved(_oldBurner);
    }

    /**
     * @notice Pass the owner role to a new address, only the owner can change the owner
     * @param _newOwner New owner's address
     */
    function passOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
        emit OwnerChanged(msg.sender, _newOwner);
    }

    /**
     * @notice Release the ownership to zero address, can never get back !
     */
    function releaseOwnership() public onlyOwner {
        owner = address(0);
        emit ReleaseOwnership(msg.sender);
    }

    /**
     * @notice Mint tokens
     * @param _account Receiver's address
     * @param _amount Amount to be minted
     */
    function mint(address _account, uint256 _amount)
        public
        notExceedCap(_amount)
        inMinterList(msg.sender)
    {
        _mint(_account, _amount); // ERC20 method with an event
    }

    /**
     * @notice Mint tokens by the owner
     * @param _account Receiver's address (Should be the lockDegis contract)
     * @param _amount Amount to be minted
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
     * @param _account address
     * @param _amount amount to be burned
     */
    function burn(address _account, uint256 _amount)
        public
        inBurnerList(msg.sender)
    {
        _burn(_account, _amount);
    }
}
