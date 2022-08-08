//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "../interfaces/ICancellationRegistry.sol";

contract LootBox is ERC721Enumerable, Ownable {
  using ECDSA for bytes32;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  mapping(uint256 => address) public tokenBurner;

  // Optional mapping for token URIs
  mapping(uint256 => string) private _tokenURIs;

  event RedeemedLootBox(uint256 rewardId, address redemeer);

  uint256 totalMinted;

  ICancellationRegistry cancellationRegistry;

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
    // _setupRole(MINTER_ROLE, payable(msg.sender));
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

  function redeem(
    uint256 rewardId,
    string memory uri,
    bytes memory signature
  ) public payable {
    require(
      !cancellationRegistry.isOrderCancelled(signature),
      "Already Cancelled"
    );
    // make sure signature is valid and get the address of the signer
    address signer = _validateSigner(rewardId, uri, msg.sender, signature);

    require(signer == owner(), "Invalid Signer");

    uint256 tokenId = totalSupply() + 1;

    // make sure that the signer is authorized to mint NFTs
    //require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");

    // first assign the token to the signer, to establish provenance on-chain
    _mint(msg.sender, tokenId);
    _setTokenURI(tokenId, uri);
    totalMinted++;

    cancellationRegistry.cancelOrder(signature);

    emit RedeemedLootBox(rewardId, msg.sender);
  }

  function _validateSigner(
    uint256 rewardId,
    string memory uri,
    address signer,
    bytes memory signature
  ) public view returns (address) {
    bytes32 BUYORDER_TYPEHASH = keccak256(
      "NFTVoucher(uint256 rewardId,address redemeer,string uri)"
    );

    bytes32 structHash = keccak256(
      abi.encode(BUYORDER_TYPEHASH, rewardId, signer, keccak256(bytes(uri)))
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
      "NFTBurn(uint256 tokenId,uint256 amount,address burner)"
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

    // Todo trasnfer of er20 token remaining

    // make sure that the signer is authorized to mint NFTs
    // require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");

    super._burn(tokenId);
  }

  /**
   * @dev See {IERC721Enumerable-totalSupply}.
   */
  function totalSupply() public view virtual override returns (uint256) {
    return totalMinted;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    // _requireMinted(tokenId);

    string memory _tokenURI = _tokenURIs[tokenId];
    string memory base = _baseURI();

    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
      return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
      return string(abi.encodePacked(base, _tokenURI));
    }

    return super.tokenURI(tokenId);
  }

  /**
   * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function _setTokenURI(uint256 tokenId, string memory _tokenURI)
    internal
    virtual
  {
    require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
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
}
