// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LootBox is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    uint256 public maxMintAmount = 20;
    address public recyclingCenter;

    //Admins Variables
    address public projectLeader;
    address[] public admins;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error AdminsUnauthorizedAccount(address account);

    event ProjectLeaderTransferred(address indexed previousLead, address indexed newLead);
    
    constructor() ERC721("Loot Box", "LOOTX") Ownable() {
        projectLeader = msg.sender;
    }

    /**
     * @dev Allows Admins to create a number of loot boxes.
     * @param _to Address to send loot box to.
     * @param _amount Amount of boxes to create.
     * @param _uri_Prefix Token URI prefix.
     * @param _uri_Suffix Token URI suffix.
     * @return uint256 array of each created loot box.
     */
    function createBoxes(address _to, uint256 _amount, string memory _uri_Prefix, string memory _uri_Suffix) public onlyAdmins returns (uint256[] memory) {
        require(_amount <= maxMintAmount, "AMOUNT MUST BE 20 or LESS");
        uint256[] memory _ids = new uint256[](_amount);
        for (uint256 i = 0; i < _amount; i++) {
            _ids[i] = createBox(_to, _uri_Prefix, _uri_Suffix);
        }
        return _ids;
    }

    /**
     * @dev Allows Admins to create a loot box.
     * @param _to Address to send loot box to.
     * @param _uri_Prefix Token URI prefix.
     * @param _uri_Suffix Token URI suffix.
     * @return uint256 of the created loot box.
     */
    function createBox(address _to, string memory _uri_Prefix, string memory _uri_Suffix) public onlyAdmins returns (uint256) {
        uint256 _id = _nextTokenId++;
        _mint(_to, _id);
        string memory _newURI = string(abi.encodePacked(_uri_Prefix, Strings.toString(_id), _uri_Suffix));
        _setTokenURI(_id, _newURI);

        return _id;
    }

    /**
     * @dev Allows Admins to edit a token uri.
     * @param _id Token ID to edit.
     * @param _uri_Prefix Token URI prefix.
     * @param _uri_Suffix Token URI suffix.
     */
    function editURI(uint256 _id, string memory _uri_Prefix, string memory _uri_Suffix) public onlyAdmins {
        string memory _newURI = string(abi.encodePacked(_uri_Prefix, Strings.toString(_id), _uri_Suffix));
        _setTokenURI(_id, _newURI);
    }

    /**
     * @dev Allows users to recycle loot boxes.
     * @param _ids Token IDs to recycle.
     */
    function recycleBoxes(uint256[] memory _ids) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            IERC721(address(this)).safeTransferFrom(msg.sender, recyclingCenter, _ids[i]);
        }
    }

    /**
     * @dev Allows Admins to set the Recycling Center address.
     * @param _recyclingAddress Address for the Recycling Center.
     */
    function setRecyclingCenter(address _recyclingAddress) external onlyAdmins {
        recyclingCenter = _recyclingAddress;
    }

    // The following functions are overrides required by Solidity.
    //*************************************************************⤵️
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
    //*************************************************************⤴️


    // The following functions are for Admins
    //_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_⤵️
    /**
     * @dev Throws if called by any account other than the owner or admin.
     */
    modifier onlyAdmins() {
        _checkAdmins();
        _;
    }

    /**
     * @dev Internal function to check if the sender is an admin.
     */
    function _checkAdmins() internal view virtual {
        if (!checkIfAdmin()) {
            revert AdminsUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Checks if the sender is an admin.
     * @return bool indicating whether the sender is an admin or not.
     */
    function checkIfAdmin() public view virtual returns(bool) {
        if (_msgSender() == owner() || _msgSender() == projectLeader){
            return true;
        }
        if(admins.length > 0){
            for (uint256 i = 0; i < admins.length; i++) {
                if(_msgSender() == admins[i]){
                    return true;
                }
            }
        }
        // Not an Admin
        return false;
    }

    /**
     * @dev Owner and Project Leader can set the addresses as approved Admins.
     * Example: ["0xADDRESS1", "0xADDRESS2", "0xADDRESS3"]
     */
    function setAdmins(address[] calldata _users) public virtual onlyAdmins {
        if (_msgSender() != owner() || _msgSender() != projectLeader) {
            revert AdminsUnauthorizedAccount(_msgSender());
        }
        delete admins;
        admins = _users;
    }

    /**
     * @dev Owner or Project Leader can set the address as new Project Leader.
     */
    function setProjectLeader(address _user) public virtual onlyAdmins {
        if (_msgSender() != owner() || _msgSender() != projectLeader) {
            revert AdminsUnauthorizedAccount(_msgSender());
        }
        address oldPL = projectLeader;
        projectLeader = _user;
        emit ProjectLeaderTransferred(oldPL, _user);
    }
    //_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_⤴️
}
