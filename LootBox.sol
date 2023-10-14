// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LootBox is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    uint256 public maxMintAmount = 20;
    
    constructor() ERC721("LootBox", "LOOTX") Ownable() {}

    function mintAmount(address _to, uint256 _amount, string memory _tokenURI_P, string memory _tokenURI_S) public onlyOwner returns (uint256[] memory) {
        require(_amount <= maxMintAmount, "AMOUNT MUST BE 20 or LESS");
        uint256[] memory _ids = new uint256[](_amount);
        for (uint256 i = 0; i < _amount; i++) {
            createBox(_to, _tokenURI_P, _tokenURI_S);
        }
        return _ids;
    }

    function createBox(address player, string memory _tokenURI_P, string memory _tokenURI_S) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(player, tokenId);
        string memory _newURI = string(abi.encodePacked(_tokenURI_P, Strings.toString(tokenId), _tokenURI_S));
        _setTokenURI(tokenId, _newURI);

        return tokenId;
    }

    function editURI(uint256 _id, string memory _tokenURI_P, string memory _tokenURI_S) public onlyOwner {
        string memory _newURI = string(abi.encodePacked(_tokenURI_P, Strings.toString(_id), _tokenURI_S));
        _setTokenURI(_id, _newURI);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}