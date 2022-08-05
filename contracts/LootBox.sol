//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract LootBox is ERC721URIStorage, AccessControl {
    using ECDSA for bytes32;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => uint256) pendingWithdrawals;

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

    constructor() ERC721("LootBox", "LootBox") {
        _setupRole(MINTER_ROLE, payable(msg.sender));
    }

    function redeem(
        uint256 tokenId,
        string memory uri,
        bytes memory signature
    ) public payable {
        // make sure signature is valid and get the address of the signer
        address signer = _validateSigner(tokenId, uri, msg.sender, signature);

        // make sure that the signer is authorized to mint NFTs
        require(
            hasRole(MINTER_ROLE, signer),
            "Signature invalid or unauthorized"
        );

        // first assign the token to the signer, to establish provenance on-chain
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function _validateSigner(
        uint256 tokenId,
        string memory uri,
        address signer,
        bytes memory signature
    ) public view returns (address) {
        bytes32 BUYORDER_TYPEHASH = keccak256(
            "NFTVoucher(uint256 tokenId,address redemeer,string uri)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                BUYORDER_TYPEHASH,
                tokenId,
                signer,
                keccak256(bytes(uri))
            )
        );

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress;
    }

    function burn(uint256 tokenId) public virtual {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}
