// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Admins.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";

/// @author developer's website 🐸 https://www.halfsupershop.com/ 🐸
contract Loot is Admins, ReentrancyGuard {
    
    mapping(uint256 => bytes32) public contestID;
    mapping(uint256 => uint256) public availableLootBoxes;
    mapping(address => mapping(uint256 => uint256)) public lootBoxVoucher;
    mapping(address => bool) public voucherOnly;
    mapping(address => bool) public allowableLoot;

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
    error LootUnavailable(uint256 lootBoxID);
    /* 
    address(0) = 0x0000000000000000000000000000000000000000
    */

    constructor() Admins(msg.sender) {
        initTokenBundles();
    }

    // ✅ Added claimLoot Function To Merge Similar Loot Into A Single Box For Single Transaction Costs By Other Users ✅
    // ⭕️   Utilize ERC-6551:
    //      No change needed to current implementation here in this contract,
    //      a Loot Box ERC-721 token contract can be minted to hold multiple token types in one token as a TBA.    ⭕️

    /**
     * @dev Allow admins to set contest root.
     * @param _contestID The contest to edit root.
     * @param _root Root for contest.
     */
    function setContest(uint256 _contestID, bytes32 _root) public onlyAdmins {
        contestID[_contestID] = _root;
    }

    /**
     * @dev Allow admins to set the allow flag for token contract.
     * @param _tokenAddress The token contract address.
     * @param _allow Flag to allow token contract.
     */
    function setAllowedContract(address _tokenAddress, bool _allow) public onlyAdmins {
        allowableLoot[_tokenAddress] = _allow;
    }

    /**
     * @dev Allow user to set flag to claim loot later.
     * @param _claimAllLater Flag to claim loot later.
     */
    function setClaimOption(bool _claimAllLater) public {
        voucherOnly[msg.sender] = _claimAllLater;
    }

    /**
     * @dev Allow admins to set an operator for specific token address.
     * @param _tokenType Types are either 20, 721, or 1155.
     * @param _tokenAddress The token contract address.
     * @param _operator The operator's address.
     * @param _approved Flag to allow or revoke operator permission.
     * @param _erc20AllowAmount Amount of ERC20 tokens allowed.
     * Note: An approved operator will only be able to move the tokens within this contract.
     */
    function setApproval(uint256 _tokenType, address _tokenAddress, address _operator, bool _approved, uint256 _erc20AllowAmount) public onlyAdmins {
        require(_tokenType == 20 || _tokenType == 721 || _tokenType == 1155, "Invalid token type.");

        if (_tokenType == 20) {
            require(_erc20AllowAmount <= IERC20(_tokenAddress).balanceOf(address(this)), "Insufficient contract balance");
            IERC20(_tokenAddress).approve(_operator, _erc20AllowAmount);
        }

        if (_tokenType == 721) {
            IERC721(_tokenAddress).setApprovalForAll(_operator, _approved);
        }

        if (_tokenType == 1155) {
            IERC1155(_tokenAddress).setApprovalForAll(_operator, _approved);
        }
    }

    /**
     * @dev Function to add ERC20 token(s) to the bundle array.
     * @param _from The address the ERC20 tokens are coming from.
     * @param _tokenAddress The contract of the ERC20 tokens.
     * @param _amount The amount (in WEI) of ERC20 tokens for this bundle.
     * @param _bundleQty The amount of times to multiply the bundle.
     */
    function addERC20Token(address _from, address _tokenAddress, uint256 _amount, uint256 _bundleQty) public onlyAdmins {
        require(_amount > 0, "Amount must be greater than zero");
        require(allowableLoot[_tokenAddress], "Token Address Not Allowed");
        IERC20(_tokenAddress).transferFrom(_from, address(this), (_amount * _bundleQty));

        // Create a new ERC20Token instance
        ERC20Token memory newToken = ERC20Token({
            tokenAddress: _tokenAddress,
            balance: _amount
        });

        // Add the new bundle to the array
        ERC20BundleID.push(newToken);
    }

    /**
     * @dev Function to add ERC721 token(s) to the bundle array.
     * @param _from The address the ERC721 tokens are coming from.
     * @param _tokenAddress The contract of the ERC721 tokens.
     * @param _tokenIDs The token IDs for this bundle.
     */
    function addERC721Token(address _from, address _tokenAddress, uint256[] calldata _tokenIDs) public onlyAdmins {
        require(_tokenIDs.length > 0, "Must have token IDs");
        require(allowableLoot[_tokenAddress], "Token Address Not Allowed");
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            IERC721(_tokenAddress).transferFrom(_from, address(this), _tokenIDs[i]);
        }
        
        // Create a new ERC721Token instance
        ERC721Token memory newToken = ERC721Token({
            tokenAddress: _tokenAddress,
            tokenIDs: _tokenIDs
        });

        ERC721BundleID.push(newToken);
    }

    /**
     * @dev Function to add ERC1155 token(s) to the bundle array.
     * @param _from The address the ERC1155 tokens are coming from.
     * @param _tokenAddress The contract of the ERC1155 tokens.
     * @param _tokenIDs The token IDs for this bundle.
     * @param _amounts The amount of each ID for this bundle.
     * @param _depositAmount The amount to deposit into this contract.
     */
    function addERC1155Token(address _from, address _tokenAddress, uint256[] calldata _tokenIDs, uint256[] calldata _amounts, uint256[] calldata _depositAmount) public onlyAdmins {
        require(_tokenIDs.length > 0, "Must have token IDs");
        require(allowableLoot[_tokenAddress], "Token Address Not Allowed");
        IERC1155(_tokenAddress).safeBatchTransferFrom(_from, address(this), _tokenIDs, _depositAmount, "");
        
        // Create a new ERC1155Token instance
        ERC1155Token memory newToken = ERC1155Token({
            tokenAddress: _tokenAddress,
            tokenIDs: _tokenIDs,
            balances: _amounts
        });

        // Add the new bundle to the array
        ERC1155BundleID.push(newToken);
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

        // Set available quantity if no ERC721, else set to 1 by default
        if(_ERC721BundleID == 0) {
            availableLootBoxes[newLootBoxID] = _qty;
        }
        else{
            availableLootBoxes[newLootBoxID] = 1;
        }
        
        // Emit an event to log the creation
        emit LootBoxCreated(newLootBoxID, msg.sender);
        
        return newLootBoxID;
    }

    /**
     * @dev Allows the user an attempt to claim a specified loot box or voucher.
     * @param proofLoot bytes32 array for proof of loot.
     * @param proofPlayer bytes32 array for proof of player.
     * @param _LootID Unique loot ID.
     * @param _LootBoxID Specified loot box ID.
     * Note: WARNING - Unauthorized attempts may cause user negative effects, NO CHEATING.
     */
    function tryClaimLoot(bytes32[] memory proofLoot, bytes32[] memory proofPlayer, uint256 _LootID, uint256 _LootBoxID, bool claimLater) public nonReentrant {
        require(verifyClaim(proofLoot, _LootID, _LootBoxID), "Cannot claim loot.");

        if(contestID[_LootID] != bytes32(0)){
            require(verifyPlayer(proofPlayer, _LootID, msg.sender), "Not entered in contest.");
        }

        if(availableLootBoxes[_LootBoxID] <= 0){
            revert LootAlreadyClaimed(_LootBoxID);
        }
        
        bool _voucher;
        // does contract hold all the tokens in the given loot box
        if(!thisHasThatLoot(_LootBoxID, 0)){
            _voucher = true;
        }

        // sub from available LootBox quantity
        availableLootBoxes[_LootBoxID]--;
        
        if(availableLootBoxes[_LootBoxID] <= 0){
            // last of the loob box supply, mark as claimed
            LootBoxID[_LootBoxID].claimed = true;
        }

        if(voucherOnly[msg.sender] || claimLater || _voucher){
            // Claim Later voucher assigned for claimer
            //     - For instance if a user doesn't have enough for gas.
            //     - User wants to claim/send loot with another wallet.
            //     - User would prefer claiming from contract.
            //     - User forgot or was unaware to pickup the loot box drop.
            //     - Contract does not hold the loot for the loot box yet.
            lootBoxVoucher[msg.sender][_LootBoxID]++;
            return;
        }
        else{
            // Claim Now
            iClaim(msg.sender, _LootBoxID, 1);
        }
    }

    /**
     * @notice Allows a user to claim loot from a specific Loot Box.
     * @param claimer The address of the user claiming the loot.
     * @param _LootBoxID The unique ID of the Loot Box being claimed.
     * @param _MergeClaim Flag to indicate whether to merge multiple vouchers for a single claim.
     * @dev Users must have a valid voucher for the specified Loot Box to claim loot.
     * @dev If `_MergeClaim` is true, the user can claim multiple loot items together if they have enough vouchers.
     */
    function claimLoot(address claimer, uint256 _LootBoxID, bool _MergeClaim) public nonReentrant {
        if(lootBoxVoucher[claimer][_LootBoxID] <= 0 || !thisHasThatLoot(_LootBoxID, 0)){
            revert LootUnavailable(_LootBoxID);
        }

        if(_MergeClaim){
            uint256 multiClaimCount = lootBoxVoucher[claimer][_LootBoxID];
            require(multiClaimCount > 1, "Similar Vouchers Required");
            lootBoxVoucher[claimer][_LootBoxID] -= multiClaimCount;
            iClaim(claimer, _LootBoxID, multiClaimCount);
        }
        else{
            lootBoxVoucher[claimer][_LootBoxID]--;
            iClaim(claimer, _LootBoxID, 1);
        }
    }

    /**
     * @notice Internal function to process loot claims for a specified Loot Box.
     * @param claimer The address of the user claiming the loot.
     * @param _LootBoxID The unique ID of the Loot Box being claimed.
     * @param claimCount The number of loot items to claim.
     * @dev Ensures the Loot Box is available and has not been claimed.
     * @dev Transfers ERC20, ERC721, and ERC1155 tokens to the claimer based on the Loot Box contents.
     */
    function iClaim(address claimer, uint256 _LootBoxID, uint256 claimCount) internal nonReentrant {
        //❌ ADD REQUIREMENTS FUNCTION TO OPEN LOOT BOX ❌
        address _erc20_Contract = LootBoxID[_LootBoxID].erc20.tokenAddress;
        address _erc721_Contract = LootBoxID[_LootBoxID].erc721.tokenAddress;
        address _erc1155_Contract = LootBoxID[_LootBoxID].erc1155.tokenAddress;

        if(availableLootBoxes[_LootBoxID] <= 0){
            // second check if last of the loot box supply, mark as claimed
            LootBoxID[_LootBoxID].claimed = true;
        }

        if(_erc20_Contract != address(0)){
            uint256 _erc20_LootAmount = LootBoxID[_LootBoxID].erc20.balance;
            // Send ERC20 tokens to claimer
            IERC20(_erc20_Contract).transfer(claimer, (_erc20_LootAmount * claimCount));
        }
        
        if(_erc721_Contract != address(0)){
            uint256[] storage _erc721_LootTokens = LootBoxID[_LootBoxID].erc721.tokenIDs;
            // Send ERC721 tokens to claimer
            for (uint256 i = 0; i < _erc721_LootTokens.length; i++) {
                IERC721(_erc721_Contract).safeTransferFrom(address(this), claimer, _erc721_LootTokens[i]);
            }
        }
        
        if(_erc1155_Contract != address(0)){
            uint256[] storage _erc1155_LootTokens = LootBoxID[_LootBoxID].erc1155.tokenIDs;
            uint256[] memory _erc1155_LootAmounts = multiplyArray(LootBoxID[_LootBoxID].erc1155.balances, claimCount);
            // Send ERC1155 tokens to claimer
            IERC1155(_erc1155_Contract).safeBatchTransferFrom(address(this), claimer, _erc1155_LootTokens, _erc1155_LootAmounts,"");
        }
    }

    /**
     * @dev Verify if this contract has the Loot for a specified LootBox.
     * @param _LootBoxID Specified loot box ID.
     * @param _tokenType Types are either 20, 721, 1155, or 0 for all three types.
     * Note: If token address is address(0) it is skipped over and defaults as true.
     */
    function thisHasThatLoot(uint256 _LootBoxID, uint256 _tokenType) public view returns (bool) {
        require(_tokenType == 0 || _tokenType == 20 || _tokenType == 721 || _tokenType == 1155, "Invalid token type.");

        ERC20Token storage erc20Token = LootBoxID[_LootBoxID].erc20;
        ERC721Token storage erc721Token = LootBoxID[_LootBoxID].erc721;
        ERC1155Token storage erc1155Token = LootBoxID[_LootBoxID].erc1155;

        if ((_tokenType == 0 || _tokenType == 20) && erc20Token.tokenAddress != address(0) && erc20BalanceOf(erc20Token.tokenAddress, address(this)) < erc20Token.balance){
            return false;
        }

        if ((_tokenType == 0 || _tokenType == 721) && erc721Token.tokenAddress != address(0)){
            uint256[] storage erc721TokenIDs = erc721Token.tokenIDs;
            uint256 erc721TokenIDsLength = erc721TokenIDs.length;

            for (uint256 i = 0; i < erc721TokenIDsLength; i++) {
                uint256 _tokenID = erc721TokenIDs[i];
                if (erc721OwnerOf(erc721Token.tokenAddress, _tokenID, address(this)) < 1) {
                    return false;
                }
            }
        }

        if ((_tokenType == 0 || _tokenType == 1155) && erc1155Token.tokenAddress != address(0)){
            uint256[] storage erc1155TokenIDs = erc1155Token.tokenIDs;
            uint256[] storage erc1155Balances = erc1155Token.balances;
            uint256 erc1155TokenIDsLength = erc1155TokenIDs.length;

            uint256[] memory _balances = erc1155BalanceOfBatch(erc1155Token.tokenAddress, erc1155TokenIDs, repeatAddressArray(address(this), erc1155TokenIDsLength), false);

            for (uint256 i = 0; i < erc1155TokenIDsLength; i++) {
                uint256 _tokenAmount = erc1155Balances[i];
                if (_balances[i] < _tokenAmount) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * @dev Returns the ERC20 token balance of an address.
     * @param _tokenAddress ERC20 token address.
     * @param _checkAddress Address to check the balance of.
     */
    function erc20BalanceOf(address _tokenAddress, address _checkAddress) public view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(_checkAddress);
    }

    /**
     * @dev Returns the ERC721 token balance of an address.
     * @param _tokenAddress ERC721 token address.
     * @param _tokenID Token ID to check.
     * @param _checkAddress Address to check the balance of the specified token ID.
     * Note: If 0 is returned the check address doesn't own the token ID.
     */
    function erc721OwnerOf(address _tokenAddress, uint256 _tokenID, address _checkAddress) public view returns (uint256) {
        if (IERC721(_tokenAddress).ownerOf(_tokenID) == _checkAddress){
            return 1;
        }
        return 0;
    }

    /**
     * @dev Returns the ERC1155 token balance of an address.
     * @param _tokenAddress ERC1155 token address.
     * @param _tokenID Token ID to check.
     * @param _checkAddress Address to check the balance of the specified token ID.
     * Note: If 0 is returned the check address doesn't own the token ID.
     */
    function erc1155BalanceOf(address _tokenAddress, uint256 _tokenID, address _checkAddress) public view returns (uint256) {
        return IERC1155(_tokenAddress).balanceOf(_checkAddress, _tokenID);
    }

    /**
     * @dev Returns the ERC1155 token balance of an address.
     * @param _tokenAddress ERC1155 token address.
     * @param _tokenIDs Token ID to check.
     * @param _checkAddresses Addresses to check the balance of the specified token ID.
     * @param _use1stAddressOnly Flag if using only the first address in _checkAddresses.
     * Note: Returns the balances of each tokenID, if 0 is returned the check address doesn't own the token ID of that index.
     */
    function erc1155BalanceOfBatch(address _tokenAddress, uint256[] memory _tokenIDs, address[] memory _checkAddresses, bool _use1stAddressOnly) public view returns (uint256[] memory) {
        if(_use1stAddressOnly){
            return IERC1155(_tokenAddress).balanceOfBatch(repeatAddressArray(_checkAddresses[0], _tokenIDs.length), _tokenIDs);
        }
        return IERC1155(_tokenAddress).balanceOfBatch(_checkAddresses, _tokenIDs);
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
     * @dev Returns the address as an array with the specified length.
     * @param _address Address to repeat.
     * @param _length Length of the array to repeat the address.
     */
    function repeatAddressArray(address _address, uint256 _length) public pure returns (address[] memory) {
        address[] memory addressArray = new address[](_length);
        for (uint256 i = 0; i < _length; i++) {
            addressArray[i] = _address;
        }
        return addressArray;
    }

    /**
     * @notice Multiplies each element of the input array by the given multiplier.
     * @param _array The array of uint256 values to be multiplied.
     * @param _multiplyAmount The multiplier to apply to each element.
     * @return _resultArray An array of uint256 values, where each element is the product of the corresponding element in the input array and the multiplier.
     */
    function multiplyArray(uint256[] memory _array, uint256 _multiplyAmount) public pure returns(uint256[] memory) {
        uint256[] memory _resultArray = new uint256[](_array.length);
        for (uint256 i = 0; i < _array.length; i++) {
            _resultArray[i] = (_array[i] * _multiplyAmount);
        }
        return _resultArray;
    }

    /**
     * @dev Verify if the Loot can be claimed.
     * @param proof bytes32 array for proof.
     * @param _LootID Unique loot ID.
     * @param _LootBoxID Specified loot box ID.
     */
    function verifyClaim(bytes32[] memory proof, uint256 _LootID, uint256 _LootBoxID) public view returns (bool) {
        if (proof.length != 0 && !LootBoxID[_LootBoxID].claimed){
            if (MerkleProof.verify(proof, LootBoxID[_LootBoxID].root, bytes32(_LootID))) {
                return (true);
            }
        }
        return (false);
    }

    /**
     * @dev Verify if user is a contestant.
     * @param proof bytes32 array for proof.
     * @param _contestID Contest ID to get root.
     * @param _player Player to check.
     */
    function verifyPlayer(bytes32[] memory proof, uint256 _contestID, address _player) public view returns (bool) {
        if (proof.length != 0){
            if (MerkleProof.verify(proof, contestID[_contestID], keccak256(abi.encodePacked(_player)))){
                return (true);
            }
        }
        return (false);
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
