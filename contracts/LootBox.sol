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

    mapping(uint256 => bool) public alreadyMinted;

    mapping(uint256 => address) public tokenBurner;

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
        // just to make sure no to mint specific tokenId after burning
        require(!alreadyMinted[tokenId], "Token Already Minted");
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
        alreadyMinted[tokenId] = true;
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

    function _validateSignToRedeem(
        uint256 tokenId,
        uint256 amount,
        address burner,
        bytes memory signature
    ) public view returns (address) {
        bytes32 BUYORDER_TYPEHASH = keccak256(
            "NFTBurn(uint256 tokenId,uint256 amount, uint256 burner)"
        );

        bytes32 structHash = keccak256(
            abi.encode(BUYORDER_TYPEHASH, tokenId, amount, burner)
        );

        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress;
    }

    function burnAndReveal(
        uint256 tokenId,
        uint256 amount,
        bytes memory signature
    ) public virtual {
        address signer = _validateSignToRedeem(
            tokenId,
            amount,
            msg.sender,
            signature
        );

        // make sure that the signer is authorized to mint NFTs
        require(
            hasRole(MINTER_ROLE, signer),
            "Signature invalid or unauthorized"
        );

        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from != address(0)) {
            address owner = ownerOf(tokenId);
            require(
                owner == msg.sender,
                "Only the owner of NFT can transfer or burn it"
            );
        }
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
