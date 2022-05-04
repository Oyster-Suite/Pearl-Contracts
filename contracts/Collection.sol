//SPDX-License-Identifier: UNLICENSED

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Collection is Ownable{

    IERC721 NFT;
    
    struct directListing{
        address owner;
        uint price;
    }

    struct auctionListing{
        address owner;
        uint timeEnd;
        uint highestBid;
        address highestBidder;
    }

    uint public FEE = 200; //2% since we divide by 10_000
    uint public FEEBalance;
    mapping(address=>uint) public balance;
    mapping(uint=>uint) public listed; //0 - not, 1 = direct, 2 = auction

    mapping(uint=>directListing) public directSales;
    mapping(uint=>auctionListing) public auctionSales;

    event tokenListed(address indexed owner,uint indexed tokenId);

    constructor(address _collection) {
        NFT = IERC721(_collection);
    }
   

    //@notice direct listing
    function listToken(uint tokenId,uint price) external {
        require(NFT.ownerOf(tokenId) == msg.sender,"Not owner");
        require(price != 0,"Can't sell for free");
        NFT.transferFrom(msg.sender, address(this), tokenId);
        listed[tokenId] = 1;
        directSales[tokenId] = directListing(msg.sender,price);
        emit tokenListed(msg.sender, tokenId);
    }
    
    //@notice auction listing
    function listToken(uint tokenId,uint price,uint duration) external {
        require(NFT.ownerOf(tokenId) == msg.sender,"Not owner");
        require(duration < 14 days,"Auction can't last more than 14 days");
        require(price != 0,"Can't start at 0");
        NFT.transferFrom(msg.sender,address(this),tokenId);
        listed[tokenId] = 2;
        auctionSales[tokenId] = auctionListing(msg.sender,block.timestamp + duration,price,address(0));
        emit tokenListed(msg.sender, tokenId);
    }

    function buyToken(uint tokenId) external payable{
        require(listed[tokenId] == 1,"Token not direct listed");
        directListing storage listing = directSales[tokenId];
        require(listing.owner != msg.sender,"Can't buy own token");
        require(msg.value >= listing.price,"Not enough paid");
        uint fee = msg.value * FEE/10_000;
        balance[listing.owner] += msg.value - fee;
        FEEBalance += fee;
        NFT.transferFrom(address(this),msg.sender,tokenId);
        delete directSales[tokenId];
        delete listed[tokenId];
    }

    function bidToken(uint tokenId) external payable{
        require(listed[tokenId] == 2,"Token not auction listed");
        auctionListing storage listing = auctionSales[tokenId];
        require(listing.owner != msg.sender,"Can't buy own token");
        require(msg.value > listing.highestBid,"Bid higher");
        require(msg.sender != listing.highestBidder,"Can't bid twice");
        require(block.timestamp < listing.timeEnd,"Auction over");
        if(listing.highestBidder != address(0)){
            balance[listing.highestBidder] += listing.highestBid;
        }
        listing.highestBid = msg.value;
        listing.highestBidder = msg.sender;
    }

    function retrieveToken(uint tokenId) external{
        require(listed[tokenId] == 2,"Token not auction listed");
        auctionListing storage listing = auctionSales[tokenId];
        require(block.timestamp >= listing.timeEnd,"Auction over");
        if(listing.highestBidder != address(0)){
            require(msg.sender == listing.highestBidder,"Not highest bidder");
            uint fee = listing.highestBid * FEE/10_000;
            balance[listing.owner] += listing.highestBid - fee;
            FEEBalance += fee;
            NFT.transferFrom(address(this),msg.sender,tokenId);
        }
        else{
            require(msg.sender == listing.owner,"Not owner");
            NFT.transferFrom(address(this),msg.sender,tokenId);
        }
        delete auctionSales[tokenId];
        delete listed[tokenId];
    }

    function retrieveBalance() external {
        uint amount = balance[msg.sender];
        balance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function retrieveFee() external onlyOwner{
        uint amount = FEEBalance;
        FEEBalance = 0;
        payable(msg.sender).transfer(amount);
    }

    function setFee(uint _fee) external onlyOwner{
        FEE = _fee;
    }

}