// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@tableland/evm/contracts/utils/TablelandDeployments.sol";
import "@tableland/evm/contracts/utils/SQLHelpers.sol";

contract NebulaNFT is
    ERC721URIStorageUpgradeable,
    ERC721HolderUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private _baseURIString;
    string private _metadataTable;
    uint256 private _metadataTableId;
    string private _tablePrefix;
    // In a separate tutorial, we update this with a Nuxt app that displays x,y
    // and gives you the interface to move x,y.
    string private _externalURL;

    event MakeMove(address caller, uint256 tokenId, uint256 x, uint256 y);

    function initialize(
        string memory baseURI,
        string memory externalURL
    ) public initializer {
        __ERC721URIStorage_init();
        __ERC721Holder_init();
        __Ownable_init_unchained();
        __Pausable_init();
        __ReentrancyGuard_init();

        _baseURIString = baseURI;
        _tablePrefix = "NebulaNFT";
        _externalURL = externalURL;
    }

    /*
     * `createMetadataTable` initializes the token tables.
     */
    function createMetadataTable()
        external
        payable
        onlyOwner
        returns (uint256)
    {
        _metadataTableId = TablelandDeployments.get().create(
            address(this),
            /*
             *  CREATE TABLE prefix_chainId (
             *  text name, 
             *  int health, 
             *  int strength, 
             *  int attack, 
             *  int speed, 
             *  text superPower, 
             *  int id, 
             *  int totalWins, 
             *  int totalLoss, 
             *  int price, 
             *  text owner
             *  );
             */
            SQLHelpers.toCreateFromSchema("id int primary key, name text, owner text, price int, health int, strength int, attack int, speed int, superPower text, totalWins int, totalLoss int", _tablePrefix)
        );

        _metadataTable = SQLHelpers.toNameFromId(
            _tablePrefix,
            _metadataTableId
        );

        return _metadataTableId;
    }

    /*
     * `safeMint` allows anyone to mint a token in this project.
     * Any time a token is minted, a new row of metadata will be
     * dynamically inserted into the metadata table.
     */

    //  Godzilla = new Character("Godzilla", 80, 8, 15, 10, "Thunderbolt", 270);

    function safeMint(address to) public returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        // Insert table values upon minting.
        TablelandDeployments.get().mutate(
            address(this),
            _metadataTableId,
            SQLHelpers.toInsert(
                _tablePrefix,
                _metadataTableId,
                "id, name, owner, price, health, strength, attack, speed, superPower, totalWins, totalLoss",
                string.concat(
                Strings.toString(newItemId),
                ",'Godzilla','",
                Strings.toHexString(to),
                "',20,80,8,15,10,'Thunderbolt',0,0"
                )
            )
        );
        _safeMint(to, newItemId);
        _tokenIds.increment();
        return newItemId;
    }


      /*
     * `_transfer` update the transfer function so that.
     * when called the owner is updated in the metadata table.
     * This is a simple example of how to update a row in the table
     */


    function _transfer(address from, address to, uint256 tokenId) internal override {
        // Call parent _transfer function to perform the transfer
        super._transfer(from, to, tokenId);

        string memory setters = string.concat("owner='", Strings.toHexString(to), "'");
        string memory filters = string.concat("id=", Strings.toString(tokenId));

        // Update owner in the SQL table
        TablelandDeployments.get().mutate(
            address(this),
            _metadataTableId,
            SQLHelpers.toUpdate(
                _tablePrefix,
                _metadataTableId,
                setters,
                filters
            )
        );
    }


    function updateBattleround(uint256 tokenId, uint256 health, uint256 strength, uint256 attack, uint256 speed, string memory superPower, uint256 totalWins, uint256 totalLoss) external {
        // Construct the setters to update other attributes
        string memory setters = string.concat(
            "health=", Strings.toString(health),
            ",strength=", Strings.toString(strength),
            ",attack=", Strings.toString(attack),
            ",speed=", Strings.toString(speed),
            ",superPower='", superPower, "'",
            ",totalWins=", Strings.toString(totalWins),
            ",totalLoss=", Strings.toString(totalLoss)
        );
    
        // Only update the row with the matching `id`
        string memory filters = string.concat("id=", Strings.toString(tokenId));
        
        // Update the table
        TablelandDeployments.get().mutate(
            address(this),
            _metadataTableId,
            SQLHelpers.toUpdate(
                _tablePrefix,
                _metadataTableId,
                setters,
                filters
            )
        );
    }


    /*
     * `_baseURI` returns the base token URI.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURIString;
    }

    /*
     * `tokenURI` is an example of how to turn a row in your table back into
     * erc721 compliant metadata JSON. here, we do a simple SELECT statement
     * with function that converts the result into json.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
    
        string memory base = _baseURI();
    
        // Construct the SQL query to fetch metadata for the specified tokenId
        string memory sqlQuery = string(abi.encodePacked(
            "SELECT json_object(",
                "'name', name, ",
                "'owner', owner, ",
                "'price', price, ",
                "'health', health, ",
                "'strength', strength, ",
                "'attack', attack, ",
                "'speed', speed, ",
                "'superPower', superPower, ",
                "'totalWins', totalWins, ",
                "'totalLoss', totalLoss",
            ")",
            " FROM ",
            _metadataTable,
            " WHERE id = ",
            Strings.toString(tokenId)
        ));
    
        // Construct the complete URL with the SQL query
        return string(abi.encodePacked(
            base,
            "query?unwrap=true&extract=true&statement=",
            SQLHelpers.quote(sqlQuery)
        ));
    }

    
    /*
     * `setExternalURL` provides an example of how to update a field for every
     * row in an table.
     */
    function setExternalURL(string calldata externalURL) external onlyOwner {
        _externalURL = externalURL;
    }

    /**
     * `totalSupply` simply returns the total number of tokens.
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    /*
     * `_metadataTable` returns a simple SQL "SELECT *" statement.
     */
    function metadataURI() public view returns (string memory) {
        string memory base = _baseURI();
        return
            string.concat(
                base,
                "query?statement=", // Simple read query setup
                "SELECT%20*%20FROM%20",
                _metadataTable
            );
    }

    /**
     * @dev See {UUPSUpgradeable-_authorizeUpgrade}.
     */
    function _authorizeUpgrade(address) internal view override onlyOwner {} // solhint-disable no-empty-blocks
}
