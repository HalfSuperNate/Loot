// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Admins.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

/// @author developer's website 🐸 https://www.halfsupershop.com/ 🐸
contract Loot is Admins {
    
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

    event LootBoxCreated(uint256 lootBoxId, address creator);

    error Unavailable();
    error Invalid();
    /* 
    address(0) = 0x0000000000000000000000000000000000000000
    */

    constructor() Admins(msg.sender) {
        // Initialize empty data for ERC20, ERC721, and ERC1155 tokens
        initTokenBundles();
    }

    // Function to create a Loot Box
    function createLootBox(
        uint256 _ERC20BundleID,
        uint256 _ERC721BundleID,
        uint256 _ERC1155BundleID,
        bytes32 _root
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
        uint256 newLootBoxId = LootBoxID.length;
        LootBoxID.push(newLootBox);
        
        // Emit an event to log the creation
        emit LootBoxCreated(newLootBoxId, msg.sender);
        
        return newLootBoxId;
    }

    // Function to add an ERC20 token
    function addERC20Token(address _tokenAddress, uint256 _balance) public {
        // Create a new ERC20Token instance
        ERC20Token memory newToken = ERC20Token({
            tokenAddress: _tokenAddress,
            balance: _balance
        });

        // Add the new bundle to the array
        ERC20BundleID.push(newToken);
    }

    // Function to add an ERC721 token
    function addERC721Token(address _tokenAddress, uint256[] calldata _tokenIDs) public {
        // Create a new ERC721Token instance
        ERC721Token memory newToken = ERC721Token({
            tokenAddress: _tokenAddress,
            tokenIDs: _tokenIDs
        });

        // Add the new bundle to the array
        ERC721BundleID.push(newToken);
    }

    // Function to add an ERC20 token
    function addERC1155Token(address _tokenAddress, uint256[] calldata _tokenIDs, uint256[] calldata _balances) public {
        // Create a new ERC1155Token instance
        ERC1155Token memory newToken = ERC1155Token({
            tokenAddress: _tokenAddress,
            tokenIDs: _tokenIDs,
            balances: _balances
        });

        // Add the new bundle to the array
        ERC1155BundleID.push(newToken);
    }

    function initTokenBundles() internal {
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
    }

    function verifyMerkleProof(bytes32[] memory proof, bytes32 root, uint256 _LootID) public pure returns (bool) {
        // Implement Merkle proof verification logic here

        if (proof.length != 0) {
            if (MerkleProof.verify(proof, root, bytes32(_LootID))) {
                return (true);
            }
        }
        
        return (false);
    }

}