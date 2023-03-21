// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IProps  {

    function mintPropsType(address _to, uint256 _tokenId, uint256 amount) external;
    function mintBatchPropsType(uint256[] memory _tokenIds, uint256[] memory amounts) external;

}