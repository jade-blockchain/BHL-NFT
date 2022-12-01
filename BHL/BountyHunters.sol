// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


    ////       //    //   //
    //  //     //    //   //
    //    //   //    //   //
    //  //     ////////   //
    //  //     ////////   //
    //    //   //    //   //
    //  //     //    //   ////////
    ////       //    //   ////////


contract BountyHunters is ERC721A, Ownable{
    using SafeMath for uint256;
    using Strings for uint256;
  
    uint256 public MAX_SUPPLY = 10000;
    uint256 public MAX_PUBLIC_MINT = 10;
    uint256 public MAX_GOLDLIST_MINT = 10;
    uint256 public MAX_NFTPERADDRESSLIMIT = 1;
    uint256 public PUBLIC_SALE_PRICE = 0.016 ether;
    uint256 public GOLDLIST_SALE_PRICE = 0.016 ether;
    uint256 public MINETHVALUE = 0.04 ether;
    uint256 public startingIndexBlock;
    uint256 public startingIndex;

    string private baseTokenUri;
    string public placeholderTokenUri;
    string public provenance;

    bool public isRevealed;
    bool public publicSale;
    bool public goldListSale;
    bool public pause;
    bool public teamMinted;
    

    // List of addresses allowed to mint during Goldlist presale
    address[] public goldlistedAddresses;

    mapping(address => uint256) public totalPublicMint;
    mapping(address => uint256) public totalGoldlistMint;
    mapping(address => uint256) public addressMintedBalance;

    constructor() ERC721A("BountyHunters", "BHL"){
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "BountyHunters :: Cannot be called by a contract");
        _;
    }

    function mint(uint256 _quantity) external payable callerIsUser{
        require(publicSale, "BountyHunters :: Not Yet Active.");
        require((totalSupply() + _quantity) <= MAX_SUPPLY, "BountyHunters :: Cannot mint beyond max supply");
        require((totalPublicMint[msg.sender] +_quantity) <= MAX_PUBLIC_MINT, "BountyHunters :: Cannot mint beyond max mint!");
        require(msg.value >= (PUBLIC_SALE_PRICE * _quantity), "BountyHunters :: Payment is below the price");
        require((msg.sender).balance >= MINETHVALUE, "BountyHunters :: Minimum Eth balance is too low");
        uint256 ownerMintedCount = addressMintedBalance[msg.sender];
        require(ownerMintedCount + _quantity <= MAX_NFTPERADDRESSLIMIT, "BountyHunters :: Max NFT per address exceeded");

        totalPublicMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function goldlistMint(uint256 _quantity) external payable callerIsUser{
        require(goldListSale, "BountyHunters :: Minting is on Pause");
        require((totalSupply() + _quantity) <= MAX_SUPPLY, "BountyHunters :: Cannot mint beyond max supply");
        require((totalGoldlistMint[msg.sender] + _quantity)  <= MAX_GOLDLIST_MINT, "BountyHunters :: Cannot mint beyond whitelist max mint!");
        require(msg.value >= (GOLDLIST_SALE_PRICE * _quantity), "BountyHunters :: Payment is below the price");
        require((msg.sender).balance >= MINETHVALUE, "BountyHunters :: Minimum Eth balance is too low");
        uint256 ownerMintedCount = addressMintedBalance[msg.sender];
        require(ownerMintedCount + _quantity <= MAX_NFTPERADDRESSLIMIT, "BountyHunters :: Max NFT per address exceeded");
        require(isGoldlisted(msg.sender), "BountyHunters :: User is not whitelisted");

        totalGoldlistMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function isGoldlisted(address _user) public view returns (bool) {
    for (uint i = 0; i < goldlistedAddresses.length; i++) {
      if (goldlistedAddresses[i] == _user) {
        return true;
      }
    }
  
    return false;
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

    /// @dev Returns the tokenIds of the address. O(totalSupply) in complexity.
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
    unchecked {
        uint256[] memory a = new uint256[](balanceOf(owner)); 
        uint256 end = _currentIndex;
        uint256 tokenIdsIdx;
        address currOwnershipAddr;
        for (uint256 i; i < end; i++) {
            TokenOwnership memory ownership = _ownerships[i];
            if (ownership.burned) {
                continue;
            }
            if (ownership.addr != address(0)) {
                currOwnershipAddr = ownership.addr;
            }
            if (currOwnershipAddr == owner) {
                a[tokenIdsIdx++] = i;
            }
        }
        return a;    
    }
}

    function teamMint(uint256 _mintAmount, address _receiver) public onlyOwner {
         require((totalSupply() + _mintAmount) <= MAX_SUPPLY, "BountyHunters :: Cannot mint beyond max supply");

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

    function setTokenUri(string memory _baseTokenUri) external onlyOwner{
        baseTokenUri = _baseTokenUri;
    }

    function setPlaceHolderUri(string memory _placeholderTokenUri) external onlyOwner{
        placeholderTokenUri = _placeholderTokenUri;
    }

    function togglePause() external onlyOwner{
        pause = !pause;
    }

    function toggleReveal() external onlyOwner{
        isRevealed = !isRevealed;
    }

    function toggleGoldListSale() external onlyOwner{
        goldListSale = !goldListSale;
    }

    function togglePublicSale() external onlyOwner{
        publicSale = !publicSale;
    }

    function setPublicCost(uint256 _newCost) public onlyOwner {
        PUBLIC_SALE_PRICE = _newCost;
    }

    function setGoldlistCost(uint256 _newCost) public onlyOwner {
        GOLDLIST_SALE_PRICE = _newCost;
    }

    function setmaxPublicMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        MAX_PUBLIC_MINT = _newmaxMintAmount;
    }

    function setmaxGoldMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
       MAX_GOLDLIST_MINT = _newmaxMintAmount;
    }

    function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
    MAX_NFTPERADDRESSLIMIT = _limit;
    }

    function setmaxSupply(uint256 _newmaxSupply) public onlyOwner {
       MAX_SUPPLY = _newmaxSupply;
    }

    function setMinEthValue(uint256 _newminEthValue) public  onlyOwner {
        MINETHVALUE = _newminEthValue;
    }

    function setProvenance(string memory _provenance) public onlyOwner {
        provenance = _provenance;
    }

    function GoldlistUsers(address[] calldata _users) public onlyOwner {
    delete goldlistedAddresses;
    goldlistedAddresses = _users;
    }

    function withdraw() public onlyOwner {
    // This will pay MLM 3% of the initial sale.
    // =============================================================================
    (bool hs, ) = payable(0x91D40EdfF22dFea50385e873DE15FaD03994C3c2).call{value: address(this).balance * 3 / 100}("");
    require(hs);
    // =============================================================================
    
    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
    }
}
