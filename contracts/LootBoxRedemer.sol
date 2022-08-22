//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICancellationRegistry.sol";

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

    ICancellationRegistry cancellationRegistry;

    mapping(address => uint256) public claimedAmount;

    mapping(address => mapping(uint256 => uint256)) public claimedERC1155Assets;

    mapping(address => mapping(uint256 => uint256)) public lootBoxPaidDetails;

    event RedeemedBullReward(uint256 indexed amount, address indexed claimer);

    event RedeemLootBox(
        uint256 lootBoxType,
        uint256 paidAmount,
        address redeemer
    );

    /*
     * @dev Sets the registry contracts for the exchange.
     */
    function setRegistryContracts(address _cancellationRegistry)
        external
        onlyOwner
    {
        cancellationRegistry = ICancellationRegistry(_cancellationRegistry);
    }

    /**
     * @dev Change Master Address
     */
    function changeMasterAddresss(address newMasterAddress) external {
        masterAddress = newMasterAddress;
    }

    // Start of Transfer Section

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

    function _transferERC1155(
        address erc1155Address,
        uint256 collectionId,
        uint256 amount
    ) private {
        require(amount != 0, "Cannot WithDraw Zero Token");
        IERC1155(erc1155Address).safeTransferFrom(
            masterAddress,
            msg.sender,
            collectionId,
            amount,
            ""
        );
    }

    // End of Transfer Section

    //Start of Validate Section

    function _validateSigner(
        address erc1155Address,
        uint256 collectionId,
        uint256 amount,
        address redeemer,
        bytes memory signature
    ) public view returns (address) {
        bytes32 CLAIM_ERC1155_ASSETS = keccak256(
            "Reward(address erc1155Address,uint256 collectionId,uint256 amount,address redeemer)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_ERC1155_ASSETS,
                erc1155Address,
                collectionId,
                amount,
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
        address redeemer,
        bytes memory signature
    ) public view returns (address) {
        bytes32 BUYORDER_TYPEHASH = keccak256(
            "Reward(address erc20Address,uint256 amount,address redeemer)"
        );

        bytes32 structHash = keccak256(
            abi.encode(BUYORDER_TYPEHASH, erc20Address, amount, redeemer)
        );

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress;
    }

    function _validateSigner(
        uint256 lootBoxType,
        address erc20Address,
        uint256 amount,
        uint256 blockNumber,
        address redeemer,
        bytes memory signature
    ) public view returns (address) {
        bytes32 PAYORDER_TYPEHASH = keccak256(
            "Reward(uint256 lootBoxType,address erc20Address,uint256 amount,uint256 blockNumber,address redeemer)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                PAYORDER_TYPEHASH,
                lootBoxType,
                erc20Address,
                amount,
                blockNumber,
                redeemer
            )
        );

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress;
    }

    // End of Validate Section

    function redeemBull(
        uint256 amount,
        address erc20Address,
        bytes memory signature
    ) external {
        address signer = _validateSigner(
            erc20Address,
            amount,
            msg.sender,
            signature
        );
        require(signer == masterAddress, "Invalid Signer");
        address sender = msg.sender;
        uint256 remainingToken = amount - claimedAmount[sender];
        _transferERC20Reward(erc20Address, remainingToken);
        claimedAmount[sender] = amount;
        emit RedeemedBullReward(remainingToken, sender);
    }

    function redeemERC1155Assets(
        address erc1155Address,
        uint256 collectionId,
        uint256 amount,
        bytes memory signature
    ) external {
        address signer = _validateSigner(
            erc1155Address,
            collectionId,
            amount,
            msg.sender,
            signature
        );
        require(signer == masterAddress, "Invalid Signer");
        uint256 claimAbleAssetAmount = amount -
            claimedERC1155Assets[msg.sender][collectionId];
        _transferERC1155(erc1155Address, collectionId, claimAbleAssetAmount);
        claimedERC1155Assets[msg.sender][collectionId] = amount;
    }

    function payFee(
        uint256 lootBoxType,
        address erc20Address,
        uint256 amount,
        uint256 blockNumber,
        bytes memory signature
    ) external {
        require(
            blockNumber >
                cancellationRegistry.getLastTransactionBlockNumber(msg.sender),
            "Invalid Signature"
        );
        address signer = _validateSigner(
            lootBoxType,
            erc20Address,
            amount,
            blockNumber,
            msg.sender,
            signature
        );
        require(signer == masterAddress, "Invalid Signer");
        IERC20(erc20Address).transferFrom(msg.sender, masterAddress, amount);
        lootBoxPaidDetails[msg.sender][lootBoxType] += amount;
        cancellationRegistry.cancelAllPreviousSignatures(msg.sender);
        emit RedeemLootBox(lootBoxType, amount, msg.sender);
    }
}
