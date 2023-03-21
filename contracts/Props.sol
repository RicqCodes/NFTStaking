// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract MansonRiveProps is ERC1155, ERC1155Pausable, Ownable {
  using Counters for Counters.Counter;

  Counters.Counter private _propsIds;

  
  // Event on create props
  event PropsAdded(uint256 indexed tokenId, uint256 indexed maxSupply);
  event PropsMinted(address to, uint256 tokenId, uint256 amount);

  //mapping controller address to a boolean variable
  mapping(address => bool) controllers;
  
  // Mapping from address to count of props Claimed
  mapping (address => uint256) private _propsClaimed;


    // Mapping from props ID to Props
  mapping (uint256 => Props) private _props;


  struct Props {
    string uri;
    uint256 maxSupply;
    uint256 totalSupply;
  }


  constructor() ERC1155("") {}

  // Get total props added to MansonRiveProps contract
  function getTotalProps() public view returns (uint256){
    return _propsIds.current();
  }

  // Get total props that has been bought/claimed
  function getCountOfPropsClaimed(address account) public view returns (uint256){
    return _propsClaimed[account];
  }

  // Override get uri for a Props ID
  function uri(uint256 _tokenId) public view override returns (string memory) {
    return _props[_tokenId].uri;
  }

  // Get max supply for a Props ID
  function getMaxSupply(uint256 _tokenId) public view returns (uint256){
    return _props[_tokenId].maxSupply;
  }

  // Get count of furnitures minted for a Props ID
  function getTotalSupply(uint256 _tokenId) public view returns (uint256){
    return _props[_tokenId].totalSupply;
  }

  // Mint one Props
  function mintPropsType(address _to, uint256 _tokenId, uint256 amount) public {
    require(controllers[msg.sender], "Only controllers can mint");
    require(amount > 0, "amount cannot be 0");
    require(_props[_tokenId].totalSupply + amount <= _props[_tokenId].maxSupply, "Exceeds MAX_SUPPLY");
    _props[_tokenId].totalSupply += amount;
    _propsClaimed[msg.sender] += amount;
    emit PropsMinted(_to, _tokenId, amount);
    _mint(_to, _tokenId, amount, "");
  }

  // Mint batch furnitures
  // function mintBatchPropsType(uint256[] memory _tokenIds, uint256[] memory amounts) public {
  //   require(controllers[msg.sender], "Only controllers can mint");
  //    require(_tokenIds.length == amounts.length, "ERC1155: ids and amounts length mismatch");

  //     uint256 totalAmounts = 0;
    
  //    for (uint i = 0; i < _tokenIds.length; i++) {
  //     uint256 _tokenId = _tokenIds[i];
  //     uint256 amount = amounts[i];

  //    require(amount > 0, "amount cannot be 0");

  //       totalAmounts += amount;

  //   require(_props[_tokenId].totalSupply + amount <= _props[_tokenId].maxSupply, "Exceeds MAX_SUPPLY");
  //      _props[_tokenId].totalSupply += amount;

  //    }

  //    if(totalAmounts > 0){
  //      _propsClaimed[msg.sender] += totalAmounts;
  //    }

  //    _mintBatch(msg.sender, _tokenIds, amounts, "");
  //  }
  
  function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory _tokenIds, uint256[] memory amounts, bytes memory data) internal virtual override(ERC1155, ERC1155Pausable) {
    super._beforeTokenTransfer(operator, from, to, _tokenIds, amounts, data);
  }

  // Create a Props
  function addProps(string memory _propsUri, uint256 _maxSupply) onlyOwner public {
    uint256 newPropsId = _propsIds.current();

    _props[newPropsId] = Props({
      uri: _propsUri,
      maxSupply: _maxSupply,
      totalSupply: 0
    });
    
    emit PropsAdded(newPropsId, _props[newPropsId].maxSupply);

    _propsIds.increment();
  }

  
  function pause() onlyOwner public {
      _pause();
  }
  
  function unpause() onlyOwner public {
      _unpause();
  }

  function withdraw() onlyOwner public {
    uint balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function addController(address controller) external onlyOwner {
    controllers[controller] = true;
  }

  function removeController(address controller) external onlyOwner {
    controllers[controller] = false;
  }

}