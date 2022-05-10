// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BountyHunters is ERC721A, Ownable{
    using SafeMath for uint256;
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_PUBLIC_MINT = 10;
    uint256 public constant MAX_GOLDLIST_MINT = 3;
    uint256 public constant MAX_SILVERLIST_MINT = 1;
    uint256 public constant PUBLIC_SALE_PRICE = .1 ether;
    uint256 public constant GOLDLIST_SALE_PRICE = .05 ether;
    uint256 public constant SILVERLIST_SALE_PRICE = .08 ether;
    uint256 public startingIndexBlock;
    uint256 public startingIndex;

    string private baseTokenUri;
    string public placeholderTokenUri;
    string public PROVENANCE;

    bool public isRevealed;
    bool public publicSale;
    bool public goldListSale;
    bool public silverListSale;
    bool public pause;
    bool public teamMinted;

    bytes32 private goldMerkleRoot;
    bytes32 private silverMerkleRoot;

    mapping(address => uint256) public totalPublicMint;
    mapping(address => uint256) public totalGoldlistMint;
    mapping(address => uint256) public totalSilverlistMint;

    constructor() ERC721A("Bounty Hunters", "BHL"){

    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Bounty Hunters :: Cannot be called by a contract");
        _;
    }

    function mint(uint256 _quantity) external payable callerIsUser{
        require(publicSale, "Bounty Hunters :: Not Yet Active.");
        require((totalSupply() + _quantity) <= MAX_SUPPLY, "Bounty Hunters :: Beyond Max Supply");
        require((totalPublicMint[msg.sender] +_quantity) <= MAX_PUBLIC_MINT, "Bounty Hunters :: Already minted 3 times!");
        require(msg.value >= (PUBLIC_SALE_PRICE * _quantity), "Bounty Hunters :: Payment is below the price");

        totalPublicMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function goldlistMint(bytes32[] memory _merkleProof, uint256 _quantity) external payable callerIsUser{
        require(goldListSale, "Bounty Hunters :: Minting is on Pause");
        require((totalSupply() + _quantity) <= MAX_SUPPLY, "Bounty Hunters :: Cannot mint beyond max supply");
        require((totalGoldlistMint[msg.sender] + _quantity)  <= MAX_GOLDLIST_MINT, "Bounty Hunters :: Cannot mint beyond whitelist max mint!");
        require(msg.value >= (GOLDLIST_SALE_PRICE * _quantity), "Bounty Hunters :: Payment is below the price");
        //create leaf node
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, goldMerkleRoot, sender), "Bounty Hunters :: You are not whitelisted");

        totalGoldlistMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function silverlistMint(bytes32[] memory _merkleProof, uint256 _quantity) external payable callerIsUser{
        require(silverListSale, "Bounty Hunters :: Minting is on Pause");
        require((totalSupply() + _quantity) <= MAX_SUPPLY, "Bounty Hunters :: Cannot mint beyond max supply");
        require((totalSilverlistMint[msg.sender] + _quantity)  <= MAX_SILVERLIST_MINT, "Bounty Hunters :: Cannot mint beyond whitelist max mint!");
        require(msg.value >= (SILVERLIST_SALE_PRICE * _quantity), "Bounty Hunters :: Payment is below the price");
        //create leaf node
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, silverMerkleRoot, sender), "Bounty Hunters :: You are not whitelisted");

        totalSilverlistMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function setStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");
        
        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_SUPPLY;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % MAX_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    function emergencySetStartingIndexBlock() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        
        startingIndexBlock = block.number;
    }

    function teamMint(uint256 _mintAmount, address _receiver) public onlyOwner {
    _safeMint(_receiver, _mintAmount);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenUri;
    }

    //return uri for certain token
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        uint256 trueId = tokenId + 1;

        if(!isRevealed){
            return placeholderTokenUri;
        }
        //string memory baseURI = _baseURI();
        return bytes(baseTokenUri).length > 0 ? string(abi.encodePacked(baseTokenUri, trueId.toString(), ".json")) : "";
    }

    /// @dev walletOf() function shouldn't be called on-chain due to gas consumption
    function walletOf() external view returns(uint256[] memory){
        address _owner = msg.sender;
        uint256 numberOfOwnedNFT = balanceOf(_owner);
        uint256[] memory ownerIds = new uint256[](numberOfOwnedNFT);

        for(uint256 index = 0; index < numberOfOwnedNFT; index++){
            ownerIds[index] = tokenOfOwnerByIndex(_owner, index);
        }

        return ownerIds;
    }

    function setTokenUri(string memory _baseTokenUri) external onlyOwner{
        baseTokenUri = _baseTokenUri;
    }
    function setPlaceHolderUri(string memory _placeholderTokenUri) external onlyOwner{
        placeholderTokenUri = _placeholderTokenUri;
    }

    function setProvenance(string memory provenance) public onlyOwner {
        PROVENANCE = provenance;
    }

    function setGoldMerkleRoot(bytes32 _goldMerkleRoot) external onlyOwner{
        goldMerkleRoot = _goldMerkleRoot;
    }

    function getGoldMerkleRoot() external view returns (bytes32){
        return goldMerkleRoot;
    }

    function setSilverMerkleRoot(bytes32 _silverMerkleRoot) external onlyOwner{
        silverMerkleRoot = _silverMerkleRoot;
    }

    function getSilverMerkleRoot() external view returns (bytes32){
        return silverMerkleRoot;
    }

    function togglePause() external onlyOwner{
        pause = !pause;
    }

    function toggleGoldListSale() external onlyOwner{
        goldListSale = !goldListSale;
    }

    function toggleSilverListSale() external onlyOwner{
        silverListSale = !silverListSale;
    }

    function togglePublicSale() external onlyOwner{
        publicSale = !publicSale;
    }

    function toggleReveal() external onlyOwner{
        isRevealed = !isRevealed;
    }

     function withdraw() public onlyOwner {
    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
    }
}
