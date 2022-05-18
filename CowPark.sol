// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts@4.5.0/utils/Multicall.sol';
import '@openzeppelin/contracts@4.5.0/security/ReentrancyGuard.sol';
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import './ICowActivity.sol';
import '../../AdminTransfer.sol';
import '../MathX128.sol';

contract CowBlindBox2 is AdminTransfer,Multicall,ReentrancyGuard {
    ICowActivity immutable public cowAddress;
    IERC20 immutable public cc;
    VRFCoordinatorV2Interface immutable public link;
    mapping(uint=>address) public openRequest;

    uint public immutable price;
    uint public immutable minLevel;
    uint public immutable maxLevel;

    constructor(ICowActivity _cowAddress,IERC20 _cc,VRFCoordinatorV2Interface _link,uint _price,uint _minLevel,uint _maxLevel) {
        cowAddress=_cowAddress;
        cc=_cc;
        link=_link;
        price=_price;
        minLevel=_minLevel;
        maxLevel=_maxLevel;
    }

    event CowCreated(address indexed user,uint indexed tokenId,uint level);
    event BoxOpen(uint indexed requestId,address to);

    function multiOpen(address to,uint num) external {
        require(num<=16,"too much open");
        for(uint i=0;i<num;i++) {
            open(to);
        }
    }

    function open(address to) public nonReentrant {
        require(to!=address(0),"zero address");
        uint boxPrice=price;
        TransferLib.transferFrom(cc,msg.sender,address(this),boxPrice);

        uint requestId=linkRequest(1);
        openRequest[requestId]=to;

        emit BoxOpen(requestId,to);
    }

    function _open(address to,uint randomX128) internal {
        uint cowLevel=MathX128.mulX128(randomX128,maxLevel-minLevel+1)+minLevel;
        uint tokenId=cowAddress.activityCow(cowLevel,to);
        emit CowCreated(to,tokenId,cowLevel);
    }

    function linkRequest(uint32 num) internal returns(uint s_requestId) {
        s_requestId = link.requestRandomWords(
                0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04,
                1,
                3,
                1000000,
                num
            );
    }

    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomWords
    ) internal {
        address to=openRequest[requestId];
        if(to!=address(0)) {
            _open(to,(randomWords[0]&((uint(1)<<128)-1)));
            openRequest[requestId]=address(0);
        }
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) nonReentrant external {
        if (msg.sender != address(link)) {
            revert("need link");
        }
        fulfillRandomWords(requestId, randomWords);
    }
}
