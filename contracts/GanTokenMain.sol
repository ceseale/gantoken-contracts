pragma solidity ^0.4.21;
import "./GanNFT.sol";

contract GanTokenMain is GanNFT {

  struct Offer {
    bool isForSale;
    uint256 tokenId;
    address seller;
    uint value;          // in ether
    address onlySellTo;     // specify to sell only to a specific person
  }

  struct Bid {
    bool hasBid;
    uint256 tokenId;
    address bidder;
    uint value;
  }

  /// @dev mapping of balances for address
  mapping(address => uint256) public pendingWithdrawals;

  /// @dev mapping of tokenId to to an offer
  mapping(uint256 => Offer) public ganTokenOfferedForSale;

  /// @dev mapping bids to tokenIds
  mapping(uint256 => Bid) public tokenBids;

  event BidForGanTokenOffered(uint256 tokenId, uint256 value, address sender);
  event BidWithdrawn(uint256 tokenId, uint256 value, address bidder);
  event GanTokenOfferedForSale(uint256 tokenId, uint256 minSalePriceInWei, address onlySellTo);
  event GanTokenNoLongerForSale(uint256 tokenId);


  /// @notice Allow a token owner to pull sale
  /// @param tokenId The id of the token that's created
  function ganTokenNoLongerForSale(uint256 tokenId) public payable owns(tokenId) {
    ganTokenOfferedForSale[tokenId] = Offer(false, tokenId, msg.sender, 0, 0x0);

    emit GanTokenNoLongerForSale(tokenId);
  }

  /// @notice Put a token up for sale
  /// @param tokenId The id of the token that's created
  /// @param minSalePriceInWei desired price of token
  function offerGanTokenForSale(uint tokenId, uint256 minSalePriceInWei) external payable owns(tokenId) {
    ganTokenOfferedForSale[tokenId] = Offer(true, tokenId, msg.sender, minSalePriceInWei, 0x0);

    emit GanTokenOfferedForSale(tokenId, minSalePriceInWei, 0x0);
  }

  /// @notice Create a new GanToken with a id and attaches an owner
  /// @param tokenId The id of the token that's being created
  function offerGanTokenForSaleToAddress(uint tokenId, address sendTo, uint256 minSalePriceInWei) external payable {
    require(tokenIdToOwner[tokenId] == msg.sender);
    ganTokenOfferedForSale[tokenId] = Offer(true, tokenId, msg.sender, minSalePriceInWei, sendTo);

    emit GanTokenOfferedForSale(tokenId, minSalePriceInWei, sendTo);
  }

  /// @notice Allows an account to buy a NFT gan token that is up for offer
  /// the token owner must set onlySellTo to the sender
  /// @param id the id of the token
  function buyGanToken(uint256 id) public payable {
    Offer memory offer = ganTokenOfferedForSale[id];
    require(offer.isForSale);
    require(offer.onlySellTo == msg.sender && offer.onlySellTo != 0x0);
    require(msg.value == offer.value);
    require(tokenIdToOwner[id] == offer.seller);

    safeTransferFrom(offer.seller, offer.onlySellTo, id);

    ganTokenOfferedForSale[id] = Offer(false, id, offer.seller, 0, 0x0);

    pendingWithdrawals[offer.seller] += msg.value;
  }

  /// @notice Allows an account to enter a higher bid on a toekn
  /// @param tokenId the id of the token
  function enterBidForGanToken(uint256 tokenId) external payable {
    Bid memory existing = tokenBids[tokenId];
    require(tokenIdToOwner[tokenId] != msg.sender);
    require(tokenIdToOwner[tokenId] != 0x0);
    require(msg.value > existing.value);
    if (existing.value > 0) {
      // Refund the failing bid
      pendingWithdrawals[existing.bidder] += existing.value;
    }

    tokenBids[tokenId] = Bid(true, tokenId, msg.sender, msg.value);
    emit BidForGanTokenOffered(tokenId, msg.value, msg.sender);
  }

  /// @notice Allows the owner of a token to accept an outstanding bid for that token
  /// @param tokenId The id of the token that's being created
  /// @param price The desired price of token in wei
  function acceptBid(uint256 tokenId, uint256 price) external payable {
    require(tokenIdToOwner[tokenId] == msg.sender);
    Bid memory bid = tokenBids[tokenId];
    require(bid.value != 0);
    require(bid.value == price);

    safeTransferFrom(msg.sender, bid.bidder, tokenId);

    tokenBids[tokenId] = Bid(false, tokenId, address(0), 0);
    pendingWithdrawals[msg.sender] += bid.value;
  }

  /// @notice Check is a given id is on sale
  /// @param tokenId The id of the token in question
  /// @return a bool whether of not the token is on sale
  function isOnSale(uint256 tokenId) external view returns (bool) {
    return ganTokenOfferedForSale[tokenId].isForSale;
  }

  /// @notice Gets all the sale data related to a token
  /// @param tokenId The id of the token
  /// @return sale information
  function getSaleData(uint256 tokenId) public view returns (bool isForSale, address seller, uint value, address onlySellTo) {
    Offer memory offer = ganTokenOfferedForSale[tokenId];
    isForSale = offer.isForSale;
    seller = offer.seller;
    value = offer.value;
    onlySellTo = offer.onlySellTo;
  }

  /// @notice Gets all the bid data related to a token
  /// @param tokenId The id of the token
  /// @return bid information
  function getBidData(uint256 tokenId) view public returns (bool hasBid, address bidder, uint value) {
    Bid memory bid = tokenBids[tokenId];
    hasBid = bid.hasBid;
    bidder = bid.bidder;
    value = bid.value;
  }

  /// @notice Allows a bidder to withdraw their bid
  /// @param tokenId The id of the token
  function withdrawBid(uint256 tokenId) external payable {
      Bid memory bid = tokenBids[tokenId];
      require(tokenIdToOwner[tokenId] != msg.sender);
      require(tokenIdToOwner[tokenId] != 0x0);
      require(bid.bidder == msg.sender);

      emit BidWithdrawn(tokenId, bid.value, msg.sender);
      uint amount = bid.value;
      tokenBids[tokenId] = Bid(false, tokenId, 0x0, 0);
      // Refund the bid money
      msg.sender.transfer(amount);
  }

  /// @notice Allows a sender to withdraw any amount in the contrat
  function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    // Remember to zero the pending refund before
    // sending to prevent re-entrancy attacks
    pendingWithdrawals[msg.sender] = 0;
    msg.sender.transfer(amount);
  }

}

