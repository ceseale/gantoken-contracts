pragma solidity ^0.4.21;

import "./ERC721.sol";
import "./PublishInterfaces.sol";
import "./Ownable.sol";
import "./Metadata.sol";

contract GanNFT is ERC165, ERC721, ERC721Enumerable, PublishInterfaces, Ownable {

  function GanNFT() internal {
      supportedInterfaces[0x80ac58cd] = true; // ERC721
      supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
      supportedInterfaces[0x780e9d63] = true; // ERC721Enumerable
      supportedInterfaces[0x8153916a] = true; // ERC721 + 165 (not needed)
  }

  bytes4 private constant ERC721_RECEIVED = bytes4(keccak256("onERC721Received(address,uint256,bytes)"));

  // The contract that will return tokens metadata
  Metadata public erc721Metadata;

  /// @dev list of all owned face ids
  uint256[] public faceIds;

  /// @dev a mpping for all the faces
  mapping(uint256 => address) public face_mapping;

  /// @dev mapping to keep owner balances
  mapping(address => uint256) public ownershipCounts;

  /// @dev mapping to owners to an array of faces that they own
  mapping(address => uint256[]) public ownerBank;

  /// @dev mapping to approved ids
  mapping(uint256 => address) public tokenApprovals;

  /// @dev The authorized operators for each address
  mapping (address => mapping (address => bool)) internal operatorApprovals;

  /// @notice A descriptive name for a collection of NFTs in this contract
  function name() external pure returns (string) {
      return "GanToken";
  }

  /// @notice An abbreviated name for NFTs in this contract
  function symbol() external pure returns (string) {
      return "GT";
  }

  /// @dev Set the address of the sibling contract that tracks metadata.
  /// Only the contract creater can call this.
  /// @param _contractAddress The location of the contract with meta data
  function setMetadataAddress(address _contractAddress) public onlyOwner {
      erc721Metadata = Metadata(_contractAddress);
  }

  modifier canTransfer(uint256 _tokenId, address _from, address _to) {
    address owner = face_mapping[_tokenId];
    require(tokenApprovals[_tokenId] == _to || owner == _from || operatorApprovals[_to][_to]);
    _;
  }
  /// @notice checks to see if a sender owns a _tokenId
  /// @param _tokenId The identifier for an NFT
  modifier owns(uint256 _tokenId) {
    require(face_mapping[_tokenId] == msg.sender);
    _;
  }

  /// @dev This emits any time the ownership of a GanToken changes.
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  /// @dev This emits when the approved addresses for a GanToken is changed or reaffirmed.
  /// The zero address indicates there is no owner and it get reset on a transfer
  event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);

  /// @dev This emits when an operator is enabled or disabled for an owner.
  ///  The operator can manage all NFTs of the owner.
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);


  /// @dev Required for ERC-721 compliance.
  function balanceOf(address _owner) external view returns (uint256 balance) {
    balance = ownershipCounts[_owner];
  }

  /// @notice Gets the onwner of a an NFT
  /// @param _tokenId The identifier for an NFT
  /// @dev Required for ERC-721 compliance.
  function ownerOf(uint256 _tokenId) external view returns (address owner) {
    owner = face_mapping[_tokenId];
  }

  /// @notice returns all owners' tokens will return an empty array
  /// if the address has no tokens
  /// @param _owner The address of the owner in question
  function tokensOfOwner(address _owner) external view returns (uint256[]) {
    uint256 tokenCount = ownershipCounts[_owner];

    if (tokenCount == 0) {
      return new uint256[](0);
    }

    uint256[] memory result = new uint256[](tokenCount);

    for (uint256 i = 0; i < tokenCount; i++) {
      result[i] = ownerBank[_owner][i];
    }

    return result;
  }

  /// @dev creates a list of all the faceids
  function getAllFaceIds() external view returns (uint256[]) {
    uint256[] memory result = new uint256[](faceIds.length);
    for (uint i = 0; i < result.length; i++) {
      result[i] = faceIds[i];
    }

    return result;
  }

  /// @notice Create a new GanToken with a id and attaches an owner
  /// @param _noise The id of the token that's being created
  function newGanToken(uint256 _noise) external payable {
    require(msg.sender != address(0));
    require(face_mapping[_noise] == 0x0);

    faceIds.push(_noise);
    ownerBank[msg.sender].push(_noise);
    face_mapping[_noise] = msg.sender;
    ownershipCounts[msg.sender]++;

    emit Transfer(address(0), msg.sender, 0);
  }

  /// @notice Transfers the ownership of an NFT from one address to another address
  /// @dev Throws unless `msg.sender` is the current owner, an authorized
  ///  operator, or the approved address for this NFT. Throws if `_from` is
  ///  not the current owner. Throws if `_to` is the zero address. Throws if
  ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
  ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
  ///  `onERC721Received` on `_to` and throws if the return value is not
  ///  `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenId The NFT to transfer
  /// @param data Additional data with no specified format, sent in call to `_to`
  function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) public payable
  {
      _safeTransferFrom(_from, _to, _tokenId, data);
  }

  /// @notice Transfers the ownership of an NFT from one address to another address
  /// @dev This works identically to the other function with an extra data parameter,
  ///  except this function just sets data to ""
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenId The NFT to transfer
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) public payable
  {
      _safeTransferFrom(_from, _to, _tokenId, "");
  }

  /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
  ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
  ///  THEY MAY BE PERMANENTLY LOST
  /// @dev Throws unless `msg.sender` is the current owner, an authorized
  ///  operator, or the approved address for this NFT. Throws if `_from` is
  ///  not the current owner. Throws if `_to` is the zero address. Throws if
  ///  `_tokenId` is not a valid NFT.
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenId The NFT to transfer
  function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
    require(_to != 0x0);
    require(_to != address(this));
    require(tokenApprovals[_tokenId] == msg.sender);
    require(face_mapping[_tokenId] == _from);

    _transfer(_tokenId, _to);
  }

  /// @notice Grant another address the right to transfer a specific face via
  ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
  /// @dev The zero address indicates there is no approved address.
  /// @dev Throws unless `msg.sender` is the current NFT owner, or an authorized
  ///  operator of the current owner.
  /// @dev Required for ERC-721 compliance.
  /// @param _to The address to be granted transfer approval. Pass address(0) to
  ///  clear all approvals.
  /// @param _tokenId The ID of the Kitty that can be transferred if this call succeeds.
  function approve(address _to, uint256 _tokenId) external owns(_tokenId) payable {
      // Register the approval (replacing any previous approval).
      tokenApprovals[_tokenId] = _to;

      emit Approval(msg.sender, _to, _tokenId);
  }

  /// @notice Enable or disable approval for a third party ("operator") to manage
  ///  all your asset.
  /// @dev Emits the ApprovalForAll event
  /// @param _operator Address to add to the set of authorized operators.
  /// @param _approved True if the operators is approved, false to revoke approval
  function setApprovalForAll(address _operator, bool _approved) external {
      operatorApprovals[msg.sender][_operator] = _approved;
      emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  /// @notice Get the approved address for a single NFT
  /// @param _tokenId The NFT to find the approved address for
  /// @return The approved address for this NFT, or the zero address if there is none
  function getApproved(uint256 _tokenId) external view returns (address) {
      return tokenApprovals[_tokenId];
  }

  /// @notice Query if an address is an authorized operator for another address
  /// @param _owner The address that owns the NFTs
  /// @param _operator The address that acts on behalf of the owner
  /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
  function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
      return operatorApprovals[_owner][_operator];
  }

  /// @notice Count NFTs tracked by this contract
  /// @return A count of valid NFTs tracked by this contract, where each one of
  ///  them has an assigned and queryable owner not equal to the zero address
  /// @dev Required for ERC-721 compliance.
  function totalSupply() external view returns (uint256) {
    return faceIds.length;
  }

  /// @notice Enumerate valid NFTs
  /// @param _index A counter less than `totalSupply()`
  /// @return The token identifier for index the `_index`th NFT 0 if it doesn't exist,
  function tokenByIndex(uint256 _index) external view returns (uint256) {
      return faceIds[_index];
  }

  /// @notice Enumerate NFTs assigned to an owner
  /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
  ///  `_owner` is the zero address, representing invalid NFTs.
  /// @param _owner An address where we are interested in NFTs owned by them
  /// @param _index A counter less than `balanceOf(_owner)`
  /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
  ///   (sort order not specified)
  function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256 _tokenId) {
      require(_owner != address(0));
      require(_index < ownerBank[_owner].length);
      _tokenId = ownerBank[_owner][_index];
  }

  function _transfer(uint256 _tokenId, address _to) internal {
    require(_to != address(0));

    address from = face_mapping[_tokenId];
    uint256 tokenCount = ownershipCounts[from];
    // remove from ownerBank and replace the deleted face id
    for (uint256 i = 0; i < tokenCount; i++) {
      uint256 ownedId = ownerBank[from][i];
      if (_tokenId == ownedId) {
        delete ownerBank[from][i];
        if (i != tokenCount) {
          ownerBank[from][i] = ownerBank[from][tokenCount - 1];
        }
        break;
      }
    }

    ownershipCounts[from]--;
    ownershipCounts[_to]++;
    ownerBank[_to].push(_tokenId);

    face_mapping[_tokenId] = _to;
    tokenApprovals[_tokenId] = address(0);
    emit Transfer(from, _to, 1);
  }

  /// @dev Actually perform the safeTransferFrom
  function _safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data)
      private
      canTransfer(_tokenId, _from, _to)
  {
      address owner = face_mapping[_tokenId];

      require(owner == _from);
      require(_to != address(0));
      require(_to != address(this));
      _transfer(_tokenId, _to);


      // Do the callback after everything is done to avoid reentrancy attack
      uint256 codeSize;
      assembly { codeSize := extcodesize(_to) }
      if (codeSize == 0) {
          return;
      }
      bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(_from, _tokenId, data);
      require(retval == ERC721_RECEIVED);
  }

  /// @dev Adapted from memcpy() by @arachnid (Nick Johnson <arachnid@notdot.net>)
  ///  This method is licenced under the Apache License.
  ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
  function _memcpy(uint _dest, uint _src, uint _len) private pure {
      // Copy word-length chunks while possible
      for(; _len >= 32; _len -= 32) {
          assembly {
              mstore(_dest, mload(_src))
          }
          _dest += 32;
          _src += 32;
      }

      // Copy remaining bytes
      uint256 mask = 256 ** (32 - _len) - 1;
      assembly {
          let srcpart := and(mload(_src), not(mask))
          let destpart := and(mload(_dest), mask)
          mstore(_dest, or(destpart, srcpart))
      }
  }

  /// @dev Adapted from toString(slice) by @arachnid (Nick Johnson <arachnid@notdot.net>)
  ///  This method is licenced under the Apache License.
  ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
  function _toString(bytes32[4] _rawBytes, uint256 _stringLength) private view returns (string) {
      string memory outputString = new string(_stringLength);
      uint256 outputPtr;
      uint256 bytesPtr;

      assembly {
          outputPtr := add(outputString, 32)
          bytesPtr := _rawBytes
      }

      _memcpy(outputPtr, bytesPtr, _stringLength);

      return outputString;
  }


  /// @notice Returns a URI pointing to a metadata package for this token conforming to
  ///  ERC-721 (https://github.com/ethereum/EIPs/issues/721)
  /// @param _tokenId The ID number of the GanToken whose metadata should be returned.
  function tokenMetadata(uint256 _tokenId, string _preferredTransport) external view returns (string infoUrl) {
      require(erc721Metadata != address(0));
      uint256 count;
      bytes32[4] memory buffer;

      (buffer, count) = erc721Metadata.getMetadata(_tokenId, _preferredTransport);

      return _toString(buffer, count);
  }

}
