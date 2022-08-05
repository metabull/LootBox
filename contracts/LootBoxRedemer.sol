//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICancellationRegistry.sol";
import "./LootBox.sol";

struct Reward {
    address erc20Address;
    uint256 bullTokenAmount;
    uint256 tokenId;
    address assetAddress;
    uint256 tokenAmount;
    uint256 credit;
}

contract LootBoxRedemer is Ownable {
    bytes32 private EIP712_DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 private DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPE_HASH,
                keccak256(bytes("Bullieverse")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

    address public masterAddress;

    address public erc721Address;

    ICancellationRegistry cancellationRegistry;

    mapping(address => uint256) public claimedAmount;

    event RedeemedBullReward(uint256 indexed amount, address indexed claimer);

    function changeMasterAddresss(address newMasterAddress) external {
        masterAddress = newMasterAddress;
    }

    function changeLootBoxAddresss(address newErc721Address) external {
        erc721Address = newErc721Address;
    }

    /*
     * @dev Sets the registry contracts for the exchange.
     */
    function setRegistryContracts(address _cancellationRegistry)
        external
        onlyOwner
    {
        cancellationRegistry = ICancellationRegistry(_cancellationRegistry);
    }

    function _transferERC1155(
        address assetAddress,
        address receiver,
        uint256 tokenId,
        uint256 tokenAmount
    ) private {
        IERC1155(assetAddress).safeTransferFrom(
            masterAddress,
            receiver,
            tokenId,
            tokenAmount,
            ""
        );
    }

    function _validateSigner(
        uint256 rewardId,
        address assetAddress,
        uint256 tokenId,
        uint256 tokenAmount,
        address redeemer,
        bytes memory signature
    ) public view returns (address) {
        bytes32 BUYORDER_TYPEHASH = keccak256(
            "Reward(uint256 rewardId,address assetAddress,uint256 tokenId,uint256 tokenAmount,address redeemer)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                BUYORDER_TYPEHASH,
                rewardId,
                assetAddress,
                tokenId,
                tokenAmount,
                redeemer
            )
        );

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress;
    }

    function _validateSigner(
        address erc20Address,
        uint256 amount,
        bytes memory signature
    ) public view returns (address) {
        bytes32 BUYORDER_TYPEHASH = keccak256(
            "Reward(address erc20Address, uint256 amount, address redeemer)"
        );

        bytes32 structHash = keccak256(
            abi.encode(BUYORDER_TYPEHASH, erc20Address, amount, msg.sender)
        );

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress;
    }

    function _transferERC20Reward(address erc20Address, uint256 tokenAmount)
        private
    {
        require(tokenAmount != 0, "Cannot WithDraw Zero Token");
        IERC20(erc20Address).transferFrom(
            masterAddress,
            msg.sender,
            tokenAmount * (10**18)
        );
    }

    function claimAsset(
        uint256 rewardId,
        address assetAddress,
        uint256 tokenId,
        uint256 tokenAmount,
        bytes memory signature
    ) external {
        require(
            cancellationRegistry.isOrderCancelled(signature),
            "Already Cancelled"
        );
        address signer = _validateSigner(
            rewardId,
            assetAddress,
            tokenId,
            tokenAmount,
            msg.sender,
            signature
        );
        require(masterAddress == signer, "Wrong Signer");

        _transferERC1155(assetAddress, msg.sender, tokenId, tokenAmount);
        cancellationRegistry.cancelOrder(signature);
    }

    function redeemBull(
        uint256 amount,
        address erc20Address,
        bytes memory signature
    ) external {
        _validateSigner(erc20Address, amount, signature);
        address sender = msg.sender;
        uint256 remainingToken = amount - claimedAmount[sender];
        _transferERC20Reward(erc20Address, remainingToken);
        claimedAmount[sender] = amount;
        emit RedeemedBullReward(remainingToken, sender);
    }
}
