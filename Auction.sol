// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract EnglishAuction {
    address payable public owner;
    string public itemDescription;
    bool public auctionStarted;
    bool public auctionEnded;
    bool public itemClaimed;

    address public highestBidder; //Highest bidder
    uint256 public highestBid; //Highest bid
    uint256 public minBidIncrement; //minimum increment required

    mapping(address => uint256) public pendingReturns;

    event AuctionStarted();
    event NewBid(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event ItemClaimed();
    event FundsClaimed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the  owner can call function");
        _;
    }

    //Auction is ongoing
    modifier auctionIsActive() {
        require(auctionStarted, "Auction not started");
        require(!auctionEnded, "Auction has ended");
        _;
    }

    //Auction has ended
    modifier auctionIsEnded() {
        require(auctionEnded, "Auction not ended");
        _;
    }

    constructor() {
        owner = payable(msg.sender);
    }    

    
    // Starting the auction with item description, starting bid and minimum increment requirement
    function startAuction(
        string memory _itemDescription,
        uint256 _startingBid,
        uint256 _minBidIncrementPercent
    ) public onlyOwner {
        require(!auctionStarted, "Auction already started");
        require(!auctionEnded, "Auction already ended");

        itemDescription = _itemDescription;
        highestBid = _startingBid;
        minBidIncrement = _minBidIncrementPercent;
        auctionStarted = true;

        emit AuctionStarted();
    }

    //Bid must be higher than current highest bid and increment
    function bid() public payable auctionIsActive {
        uint256 minRequiredBid = highestBid + ((highestBid * minBidIncrement) / 100);
        require(msg.value >= minRequiredBid, "Bid not high enough");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit NewBid(msg.sender, msg.value);
    }


    //The oponent whoes bid wasnt enough can withdraw the bid
    function withdraw() public {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");
        pendingReturns[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    //Owner can end teh auction anytime
    function endAuction() public onlyOwner auctionIsActive {
        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    //Highest bidder can claim his item
    function claimItem() public auctionIsEnded {
        require(msg.sender == highestBidder, "Only the highest bidder can claim the item");
        require(!itemClaimed, "Item already claimed");

        itemClaimed = true;
        emit ItemClaimed();
    }

    //the owner can claim the final bid amount
    function claimFunds() public onlyOwner auctionIsEnded {
        (bool success, ) = owner.call{value: highestBid}("");
        require(success, "Transfer to owner failed");
        emit FundsClaimed();
    }

    //Some helper functions
    function getMinimumBid() public view returns (uint256) {
        return highestBid + ((highestBid * minBidIncrement) / 100);
    }

    //Helper function 
    function getAuctionDetails() public view returns (
        string memory item,
        address leading,
        uint256 topBid,
        bool started,
        bool ended,
        bool claimed
    ) {
        return (
            itemDescription,
            highestBidder,
            highestBid,
            auctionStarted,
            auctionEnded,
            itemClaimed
        );
    }
}