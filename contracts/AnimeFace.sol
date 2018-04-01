pragma solidity ^0.4.21;
// TODO Rename all the functions to make sure the conventions work
// change minValue/minPrice to vaule and price
import "./GanNFT.sol";


contract AnimeFace is GanNFT {

  struct Offer {
    bool isForSale;
    uint256 faceId;
    address seller;
    uint minValue;          // in ether
    address onlySellTo;     // specify to sell only to a specific person
  }

  struct Bid {
    bool hasBid;
    uint256 faceId;
    address bidder;
    uint value;
  }

  /// @dev mapping of balances for address
  mapping(address => uint256) public pendingWithdrawals;

  /// @dev mapping of tokenId to to an offer
  mapping(uint256 => Offer) public faceOfferedForSale;

  /// @dev mapping bids to tokenIds
  mapping(uint256 => Bid) public faceBids;

  event BidForFaceOffered(uint256 faceId, uint256 value, address sender);
  event BidWithdrawn(uint256 faceId, uint256 value, address bidder);
  event FaceBought(uint256 faceId, uint256 value, address sender, address bidder);
  event FaceOfferedForSale(uint256 faceId, uint256 minSalePriceInWei, address onlySellTo);
  event FaceNoLongerForSale(uint256 faceId);


  /// @notice Allow a token owner to pull sale
  /// @param faceId The id of the token that's being created
  function faceNoLongerForSale(uint256 faceId) public payable owns(faceId) {
    faceOfferedForSale[faceId] = Offer(false, faceId, msg.sender, 0, 0x0);

    emit FaceNoLongerForSale(faceId);
  }

  /// @notice Put a token up for sale
  /// @param faceId The id of the token that's being created
  /// @param minSalePriceInWei desired price of token
  function offerFaceForSale(uint faceId, uint256 minSalePriceInWei) external payable owns(faceId) {
    faceOfferedForSale[faceId] = Offer(true, faceId, msg.sender, minSalePriceInWei, 0x0);

    emit FaceOfferedForSale(faceId, minSalePriceInWei, 0x0);
  }

  /// @notice Create a new GanToken with a id and attaches an owner
  /// @param faceId The id of the token that's being created
  function offerFaceForSaleToAddress(uint faceId, address sendTo, uint256 minSalePriceInWei) external payable {
    require(face_mapping[faceId] == msg.sender);
    faceOfferedForSale[faceId] = Offer(true, faceId, msg.sender, minSalePriceInWei, sendTo);

    emit FaceOfferedForSale(faceId, minSalePriceInWei, sendTo);
  }

  /// @notice Allows a account to buy a NFT gan token that is up for offer
  /// the token owner must set onlySellTo to the sender
  /// @param id the id of the token
  function buyGanToken(uint256 id) public payable {
    Offer memory offer = faceOfferedForSale[id];
    require(offer.isForSale);
    require(offer.onlySellTo == msg.sender && offer.onlySellTo != 0x0);
    require(msg.value == offer.minValue);
    require(face_mapping[id] == offer.seller);

    safeTransferFrom(offer.seller, offer.onlySellTo, id);

    faceOfferedForSale[id] = Offer(false, id, offer.seller, 0, 0x0);

    pendingWithdrawals[offer.seller] += msg.value;
  }

  /// @notice Allows an account to enter a higher bid on a toekn
  /// @param faceId the id of the token
  function enterBidForGanToken(uint256 faceId) external payable {
    Bid memory existing = faceBids[faceId];
    require(face_mapping[faceId] != msg.sender);
    require(face_mapping[faceId] != 0x0);
    require(msg.value > existing.value);
    if (existing.value > 0) {
      // Refund the failing bid
      pendingWithdrawals[existing.bidder] += existing.value;
    }

    faceBids[faceId] = Bid(true, faceId, msg.sender, msg.value);
    emit BidForFaceOffered(faceId, msg.value, msg.sender);
  }

  /// @notice Allows the owner of a token to accept an outstanding bid for that token
  /// @param noise The id of the token that's being created
  /// @param minPrice The desired price of token in wei
  function acceptBid(uint256 noise, uint256 minPrice) external payable {
    require(face_mapping[noise] == msg.sender);
    Bid memory bid = faceBids[noise];
    require(bid.value != 0);
    require(bid.value == minPrice);

    safeTransferFrom(msg.sender, bid.bidder, noise);

    faceBids[noise] = Bid(false, noise, address(0), 0);
    pendingWithdrawals[msg.sender] += bid.value;
  }

  /// @notice Check is a given id is on sale
  /// @param _noise The id of the token in question
  /// @return a bool whether of not the token is on sale
  function isOnSale(uint256 _noise) external view returns (bool) {
    return faceOfferedForSale[_noise].isForSale;
  }

  /// @notice Gets all the sale data related to a token
  /// @param _noise The id of the token
  /// @return sale information
  function getSaleData(uint256 _noise) public view returns (bool isForSale, address seller, uint minValue, address onlySellTo) {
    Offer memory offer = faceOfferedForSale[_noise];
    isForSale = offer.isForSale;
    seller = offer.seller;
    minValue = offer.minValue;
    onlySellTo = offer.onlySellTo;
  }

  /// @notice Gets all the bid data related to a token
  /// @param _noise The id of the token
  /// @return bid information
  function getBidData(uint256 _noise) view public returns (bool hasBid, address bidder, uint value) {
    Bid memory bid = faceBids[_noise];
    hasBid = bid.hasBid;
    bidder = bid.bidder;
    value = bid.value;
  }

  /// @notice Allows a bidder to withdraw their bid
  /// @param faceId The id of the token
  function withdrawBid(uint256 faceId) external payable {
      Bid memory bid = faceBids[faceId];
      require(face_mapping[faceId] != msg.sender);
      require(face_mapping[faceId] != 0x0);
      require(bid.bidder == msg.sender);

      emit BidWithdrawn(faceId, bid.value, msg.sender);
      uint amount = bid.value;
      faceBids[faceId] = Bid(false, faceId, 0x0, 0);
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

