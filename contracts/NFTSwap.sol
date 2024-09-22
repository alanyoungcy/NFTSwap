// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
/*
利用智能合约搭建一个零手续费的去中心化 NFT 交易所，主要逻辑：
- 卖家：出售 NFT 的一方，可以挂单 list、撤单 revoke、修改价格 update。
- 买家：购买 NFT 的一方，可以购买 purchase。
- 订单：卖家发布的 NFT 链上订单，一个系列的同一 tokenId 最多存在一个订单，其中包含挂单价格 price 和持有人 owner 信息。当一个订单交易完成或被撤单后，其中信息清零。
*/
 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

/*
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; 
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol"; 
*/


contract NFTSwap is IERC721Receiver {

    event List(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );

    event Purchase(
        address indexed buyer,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );

    event Revoke(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId
    );

    event Update(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    struct Order {
        address owner;
        uint256 price;
    }
    // NFT Order映射
    mapping(address => mapping(uint256 => Order)) public nftList;

    //on receiving ERC721, ensure mint and publication fo NFT
    function onERC721Received (
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external override returns (bytes4){
        return IERC721Receiver.onERC721Received.selector;
    }
 
    function fallback() external payable{}

    function list(address _nftAddr, uint256 _tokenId, uint256 _price) public{
        IERC721 _nft = IERC721(_nftAddr);
        require(_price > 0);
        require(_nft.getApproved(_tokenId) == address(this), "Seek Approval");

        Order storage _order =  nftList[_nftAddr][_tokenId]; // from the list get nft address
        _order.owner = msg.sender; //set the order owner
        _order.price = _price; //set the rprice
        // transfer nft
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        // release the event
        emit List(msg.sender, _nftAddr, _tokenId, _price);

    }


    function revoke(address _nftAddr, uint256 _tokenId ) public {
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.owner == msg.sender, "not the owner");

         IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Wrong Order");

        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete nftList[_nftAddr][_tokenId];
        emit Revoke(msg.sender,_nftAddr,_tokenId);

    }


    function purchase(address _nftAddr, uint256 _tokenId, uint256 _price) payable public{
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_price > 0, "Invalid price");
        require(msg.value >= _order.price, "Not enough value, increase price ");
        
        //require(_order.owner == msg.sender, "not the owner");
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Wrong Order");

        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        payable(_order.owner).transfer(_order.price);
        payable(msg.sender).transfer(msg.value - _order.price);
        delete nftList[_nftAddr][_tokenId];

        emit Purchase(msg.sender, _nftAddr, _tokenId, _order.price);

    }



    function update(address _nftAddr, uint256 _tokenId, uint256 _newPrice) public {
        require(_newPrice > 0, "Invalid price");
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.owner == msg.sender, "not the owner");
         IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Wrong Order");

        _order.price = _newPrice;

        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
        
    }
}