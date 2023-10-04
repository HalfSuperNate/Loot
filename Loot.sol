// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Admins.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

/// @author developer's website 🐸 https://www.halfsupershop.com/ 🐸
contract Loot is Admins {
    
    mapping(uint256 => uint256) public availableLootBoxes;
    mapping(address => mapping(uint256 => uint256)) public lootBoxVoucher;
    //mapping(address => bool) public voucherOnly;

    /*Tokens this contract holds*/
    mapping(address => uint256) public erc20ContractBalance;
    mapping(address => mapping(uint256 => bool)) public erc721ContractToken;
    mapping(address => mapping(uint256 => uint256)) public erc1155ContractBalance;

    // Struct to represent ERC20 token and its balance
    struct ERC20Token {
        address tokenAddress;
        uint256 balance;
    }

    // Struct to represent ERC721 token and its tokens
    struct ERC721Token {
        address tokenAddress;
        uint256[] tokenIDs;
    }

    // Struct to represent ERC1155 token and its tokens
    struct ERC1155Token {
        address tokenAddress;
        uint256[] tokenIDs;
        uint256[] balances;
    }

    // Struct to represent a Loot Box
    struct LootBox {
        ERC20Token erc20;
        ERC721Token erc721;
        ERC1155Token erc1155;
        bytes32 root;
        bool claimed;
    }

    /*The ID of Each Loot Box and Token Bundle*/
    LootBox[] public LootBoxID;
    ERC20Token[] public ERC20BundleID;
    ERC721Token[] public ERC721BundleID;
    ERC1155Token[] public ERC1155BundleID;

    event LootBoxCreated(uint256 lootBoxID, address creator);

    error LootAlreadyClaimed(uint256 lootBoxID);
    /* 
    address(0) = 0x0000000000000000000000000000000000000000
    */

    constructor() Admins(msg.sender) {
        initTokenBundles();
    }

    /**
     * @dev Function to create a Loot Box.
     * @param _ERC20BundleID ID of the ERC20 bundle.
     * @param _ERC721BundleID ID of the ERC721 bundle.
     * @param _ERC1155BundleID ID of the ERC1155 bundle.
     * @param _root Merkle Root for verifying the Loot Box claim.
     * @param _qty Quantity of Loot Boxes available.
     */
    function createLootBox(
        uint256 _ERC20BundleID,
        uint256 _ERC721BundleID,
        uint256 _ERC1155BundleID,
        bytes32 _root,
        uint256 _qty
    ) public onlyAdmins returns (uint256) {
        require(_ERC20BundleID > 0 || _ERC721BundleID > 0 || _ERC1155BundleID > 0, "Loot box must contain at least one type of token");

        // Create a new Loot Box
        LootBox memory newLootBox = LootBox({
            erc20: ERC20BundleID[_ERC20BundleID],
            erc721: ERC721BundleID[_ERC721BundleID],
            erc1155: ERC1155BundleID[_ERC1155BundleID],
            root: _root,
            claimed: false
        });
        
        // Add the Loot Box to the array
        uint256 newLootBoxID = LootBoxID.length;
        LootBoxID.push(newLootBox);

        // Set available quantity
        availableLootBoxes[newLootBoxID] = _qty;
        
        // Emit an event to log the creation
        emit LootBoxCreated(newLootBoxID, msg.sender);
        
        return newLootBoxID;
    }

    /**
     * @dev Function to add ERC20 token(s) to the bundle array.
     * @param _tokenAddress The contract of the ERC20 tokens.
     * @param _balance The amount (in WEI) of ERC20 tokens for this bundle.
     */
    function addERC20Token(address _tokenAddress, uint256 _balance) public onlyAdmins {
        // Create a new ERC20Token instance
        ERC20Token memory newToken = ERC20Token({
            tokenAddress: _tokenAddress,
            balance: _balance
        });

        // Add the new bundle to the array
        ERC20BundleID.push(newToken);
    }

    /**
     * @dev Function to add ERC721 token(s) to the bundle array.
     * @param _tokenAddress The contract of the ERC721 tokens.
     * @param _tokenIDs The token IDs for this bundle.
     */
    function addERC721Token(address _tokenAddress, uint256[] calldata _tokenIDs) public onlyAdmins {
        // Create a new ERC721Token instance
        ERC721Token memory newToken = ERC721Token({
            tokenAddress: _tokenAddress,
            tokenIDs: _tokenIDs
        });

        ERC721BundleID.push(newToken);
    }

    /**
     * @dev Function to add ERC1155 token(s) to the bundle array.
     * @param _tokenAddress The contract of the ERC1155 tokens.
     * @param _tokenIDs The token IDs for this bundle.
     * @param _balances The amount of each ID for this bundle.
     */
    function addERC1155Token(address _tokenAddress, uint256[] calldata _tokenIDs, uint256[] calldata _balances) public onlyAdmins {
        // Create a new ERC1155Token instance
        ERC1155Token memory newToken = ERC1155Token({
            tokenAddress: _tokenAddress,
            tokenIDs: _tokenIDs,
            balances: _balances
        });

        // Add the new bundle to the array
        ERC1155BundleID.push(newToken);
    }

    /**
     * @dev Returns array token data for a ERC721 bundle, or array token or balance data for a ERC1155 bundle.
     * @param _bundleID The bundle ID to check.
     * @param _T721F1155 Flag true if ERC721 or false if ERC1155.
     * @param _TidFamount Flag true for ERC1155 token IDs or false for ERC1155 amounts for each token ID.
     */
    function getBundleArrayData(uint256 _bundleID, bool _T721F1155, bool _TidFamount) public view returns (uint256[] memory) {
        if(_T721F1155){
            return ERC721BundleID[_bundleID].tokenIDs;
        }
        else{
            if(_TidFamount){
                return ERC1155BundleID[_bundleID].tokenIDs;
            }
            else{
                return ERC1155BundleID[_bundleID].balances;
            }
        }
    }

    /**
     * @dev Verify if the Loot can be claimed.
     * @param proof bytes32 array for proof.
     * @param _LootID Unique loot ID.
     * @param _LootBoxID Specified loot box ID.
     */
    function verifyClaim(bytes32[] memory proof, uint256 _LootID, uint256 _LootBoxID) public view returns (bool) {
        if (proof.length != 0 && !LootBoxID[_LootBoxID].claimed) {
            if (MerkleProof.verify(proof, LootBoxID[_LootBoxID].root, bytes32(_LootID))) {
                return (true);
            }
        }
        
        return (false);
    }

    /**
     * @dev Allows the user an attempt to claim a specified loot box or voucher.
     * @param proof bytes32 array for proof.
     * @param _LootID Unique loot ID.
     * @param _LootBoxID Specified loot box ID.
     * Note: WARNING - Unauthorized attempts may cause user negative effects, NO CHEATING.
     */
    function tryClaimLoot(bytes32[] memory proof, uint256 _LootID, uint256 _LootBoxID) public {
        require(verifyClaim(proof, _LootID, _LootBoxID), "Cannot claim loot.");
        address _erc20_Contract = LootBoxID[_LootBoxID].erc20.tokenAddress;
        address _erc721_Contract = LootBoxID[_LootBoxID].erc721.tokenAddress;
        address _erc1155_Contract = LootBoxID[_LootBoxID].erc1155.tokenAddress;
        uint256 voucher;

        /*
        if(voucherOnly[msg.sender]){
            // ❌ ADD FUNCTION IF USER WOULD LIKE TO CLAIM LOOT AT A LATER TIME BY CONSUMING A VOUCHER❌ 
            //     - For instance if a user doesn't have enough for gas.
            //     - User wants to claim/send loot with another wallet.
            //     - User would prefer claiming from contract.

            availableLootBoxes[_LootBoxID]--;
            lootBoxVoucher[msg.sender][_LootBoxID]++;
            return;
        }
        */

        availableLootBoxes[_LootBoxID]--;

        if(_erc20_Contract != address(0)){
            if(thisHasThatLoot(_LootBoxID, 20)){
                uint256 _erc20_LootAmount = LootBoxID[_LootBoxID].erc20.balance;
                // Send ERC20 tokens to claimer
                IERC20(_erc20_Contract).transfer(msg.sender, _erc20_LootAmount);
            }
            else{
                voucher++;
            }
        }

        if(_erc721_Contract != address(0) && voucher == 0){
            if(thisHasThatLoot(_LootBoxID, 721)){
                uint256[] storage _erc721_LootTokens = LootBoxID[_LootBoxID].erc721.tokenIDs;
                // Send ERC721 tokens to claimer
                for (uint256 i = 0; i < _erc721_LootTokens.length; i++) {
                    IERC721(_erc721_Contract).safeTransferFrom(address(this), msg.sender, _erc721_LootTokens[i]);
                }
            }
            else{
                voucher++;
            }
        }

        if(_erc1155_Contract != address(0) && voucher == 0){
            if(thisHasThatLoot(_LootBoxID, 1155)){
                uint256[] storage _erc1155_LootTokens = LootBoxID[_LootBoxID].erc1155.tokenIDs;
                uint256[] storage _erc1155_LootAmounts = LootBoxID[_LootBoxID].erc1155.balances;
                // Send ERC1155 tokens to claimer
                IERC1155(_erc1155_Contract).safeBatchTransferFrom(address(this), msg.sender, _erc1155_LootTokens, _erc1155_LootAmounts,"");
            }
            else{
                voucher++;
            }
        }

        if(voucher > 0) {
            lootBoxVoucher[msg.sender][_LootBoxID]++;
        }
    }

    /**
     * @dev Verify if this contract has the Loot for a specified LootBox.
     * @param _LootBoxID Specified loot box ID.
     * @param _tokenType Types are either 20, 721, 1155, or 0 for all three types.
     */
    function thisHasThatLoot(uint256 _LootBoxID, uint256 _tokenType) public view returns (bool) {
        require(_tokenType == 0 || _tokenType == 20 || _tokenType == 721 || _tokenType == 1155, "Invalid token type.");
        if(availableLootBoxes[_LootBoxID] <= 0){
            revert LootAlreadyClaimed(_LootBoxID);
        }

        ERC20Token storage erc20Token = LootBoxID[_LootBoxID].erc20;
        ERC721Token storage erc721Token = LootBoxID[_LootBoxID].erc721;
        ERC1155Token storage erc1155Token = LootBoxID[_LootBoxID].erc1155;

        if ((_tokenType == 0 || _tokenType == 20) && IERC20(erc20Token.tokenAddress).balanceOf(address(this)) < erc20Token.balance) {
            return false;
        }

        if (_tokenType == 0 || _tokenType == 721) {
            uint256[] storage erc721TokenIDs = erc721Token.tokenIDs;
            uint256 erc721TokenIDsLength = erc721TokenIDs.length;

            for (uint256 i = 0; i < erc721TokenIDsLength; i++) {
                uint256 _tokenID = erc721TokenIDs[i];
                if (IERC721(erc721Token.tokenAddress).ownerOf(_tokenID) != address(this)) {
                    return false;
                }
            }
        }

        if (_tokenType == 0 || _tokenType == 1155) {
            uint256[] storage erc1155TokenIDs = erc1155Token.tokenIDs;
            uint256[] storage erc1155Balances = erc1155Token.balances;
            uint256 erc1155TokenIDsLength = erc1155TokenIDs.length;

            address[] memory accountsArray = new address[](erc1155TokenIDsLength);
            for (uint256 j = 0; j < erc1155TokenIDsLength; j++) {
                accountsArray[j] = address(this);
            }

            uint256[] memory _balances = IERC1155(erc1155Token.tokenAddress).balanceOfBatch(accountsArray, erc1155TokenIDs);

            for (uint256 i = 0; i < erc1155TokenIDsLength; i++) {
                uint256 _tokenAmount = erc1155Balances[i];
                if (_balances[i] < _tokenAmount) {
                    return false;
                }
            }
        }

        return true;
    }

    // Initialize empty data for ERC20, ERC721, and ERC1155 tokens then push an empty LootBox
    function initTokenBundles() internal {
        require(LootBoxID.length == 0);
        ERC20Token memory newToken = ERC20Token({
            tokenAddress: address(0),
            balance: 0
        });

        ERC20BundleID.push(newToken);

        ERC721Token memory _newToken = ERC721Token({
            tokenAddress: address(0),
            tokenIDs: new uint256[](0)
        });

        ERC721BundleID.push(_newToken);

        ERC1155Token memory __newToken = ERC1155Token({
            tokenAddress: address(0),
            tokenIDs: new uint256[](0),
            balances: new uint256[](0)
        });

        ERC1155BundleID.push(__newToken);

        LootBox memory newLootBox = LootBox({
            erc20: newToken,
            erc721: _newToken,
            erc1155: __newToken,
            root: 0x0000000000000000000000000000000000000000000000000000000000000000,
            claimed: false
        });

        LootBoxID.push(newLootBox);
    }

}
