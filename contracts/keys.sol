   
// SPDX-License-Identifier: MIT


  /*
 .----------------.  .----------------.  .-----------------. .----------------.  .----------------.  .-----------------. .----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
| | ____    ____ | || |      __      | || | ____  _____  | || |    _______   | || |     ____     | || | ____  _____  | || |  _______     | || |     _____    | || | ____   ____  | || |  _________   | |
| ||_   \  /   _|| || |     /  \     | || ||_   \|_   _| | || |   /  ___  |  | || |   .'    `.   | || ||_   \|_   _| | || | |_   __ \    | || |    |_   _|   | || ||_  _| |_  _| | || | |_   ___  |  | |
| |  |   \/   |  | || |    / /\ \    | || |  |   \ | |   | || |  |  (__ \_|  | || |  /  .--.  \  | || |  |   \ | |   | || |   | |__) |   | || |      | |     | || |  \ \   / /   | || |   | |_  \_|  | |
| |  | |\  /| |  | || |   / ____ \   | || |  | |\ \| |   | || |   '.___`-.   | || |  | |    | |  | || |  | |\ \| |   | || |   |  __ /    | || |      | |     | || |   \ \ / /    | || |   |  _|  _   | |
| | _| |_\/_| |_ | || | _/ /    \ \_ | || | _| |_\   |_  | || |  |`\____) |  | || |  \  `--'  /  | || | _| |_\   |_  | || |  _| |  \ \_  | || |     _| |_    | || |    \ ' /     | || |  _| |___/ |  | |
| ||_____||_____|| || ||____|  |____|| || ||_____|\____| | || |  |_______.'  | || |   `.____.'   | || ||_____|\____| | || | |____| |___| | || |    |_____|   | || |     \_/      | || | |_________|  | |
| |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------' 



 .----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. |
| |  ___  ____   | || |  _________   | || |  ____  ____  | || |    _______   | |
| | |_  ||_  _|  | || | |_   ___  |  | || | |_  _||_  _| | || |   /  ___  |  | |
| |   | |_/ /    | || |   | |_  \_|  | || |   \ \  / /   | || |  |  (__ \_|  | |
| |   |  __'.    | || |   |  _|  _   | || |    \ \/ /    | || |   '.___`-.   | |
| |  _| |  \ \_  | || |  _| |___/ |  | || |    _|  |_    | || |  |`\____) |  | |
| | |____||____| | || | |_________|  | || |   |______|   | || |  |_______.'  | |
| |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------' 
  */                                                                                                                                                                                 

pragma solidity >= 0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MansonRive is ERC721Enumerable, Ownable {
  using Strings for uint256;


// PUBLIC FUNCTIONS
    string public baseURI;
    string public baseExtension = ".json";
    bool public revealed = false;
    string public notRevealedUri;
    uint256 public cost = 0.025 ether;
    uint256 public maxSupply = 6666;
    uint256 public maxMintAmountWl = 2; // WL wallets can only mint 1 free, 1 paid
    uint256 public maxMintAmountPublic = 4; // Every one can mint max of 4 Keys during public sale
    uint256 public maxMintAmountOG = 3; // 50 wallets will belong in the OG List to mint for free, 
                                        
    uint256 public teamTokensMinted; //max total of 250 keys mintuint256 public teamTokensMinted;
    bool public paused = false;
    
    bool public onlyWhitelisted = true;
    bool public onlyOG = true;

    address[] public addressOfOG;
    address[] public whitelistedAddresses;
    mapping(address => uint256) public addressMintedBalance;
    mapping(address => uint256) private addressMintedPublicBalance;

//PRIVATE VARIABLES
    uint256 private constant whitelistedSupply = 2983;// The total allocation for Free mint
    uint256 private totalWlMinted; // The total keys minted by WL wallets
    uint256 private constant publicMintSupply = 3333;// The total allocation for Paid mint
    uint256 private totalPublicMinted; // The total keys minted in the public round
    uint256 private constant maxTeamMint = 200; // The total allocation for Team.
    uint256 private constant oGSupply = 150;// The total allocation for free OG mint
    uint256 public totalOgMinted; // The total keys minted by OG
 

//EVENTS
    event Mint(address indexed sender, uint256 indexed tokenId);

//ENUMS
    enum SalePhase {
		Locked,
		WhitelistMint,
        OgMint,
		PublicSale
	}

    SalePhase public phase = SalePhase.Locked;


//MODIFIERS

  modifier SalePrice(uint _mintAmount) {
    require( msg.value >= cost * _mintAmount, "KEYS: Not enough funds");
    _;
  }

  modifier MintAmount(uint _mintAmount) {
    require(_mintAmount > 0, "KEYS: Need to mint at least 1 Key");
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _initNotRevealedUri
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
  }

// internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

// public function

  function WlMint(uint256 _mintAmount) public payable 
    MintAmount(_mintAmount) {
        uint256 supply = totalSupply();
        require(!paused, "KEYS: The contract is paused");
        require(phase == SalePhase.WhitelistMint, "KEYS: Not in whitelist mint phase");
        require(msg.sender != owner(), "KEYS: Owner cannot mint in this phase");
        require(_mintAmount <= maxMintAmountWl, "KEYS: Max mint amount exceeded");
        require(totalWlMinted + _mintAmount <= whitelistedSupply, "KEYS: Whitelist mint is full");
        require(supply + _mintAmount <= maxSupply, "KEYS: Max NFT limit exceeded");

                require(isWhitelisted(msg.sender), "KEYS: User is not whitelisted");
                uint256 ownerMintedCount = addressMintedBalance[msg.sender];

                if(ownerMintedCount == 1) {
                  require(msg.value >= cost * _mintAmount, "KEYS: not enough funds");
                }
                require(ownerMintedCount + _mintAmount <= maxMintAmountWl, "KEYS: Max NFT for whitelisted address exceeded");
  
          addressMintedBalance[msg.sender]++;
          totalWlMinted++;
          emit Mint(msg.sender, supply++);
          _safeMint(msg.sender, supply++);
      }


    function oGMint(uint256 _mintAmount) public payable 
      SalePrice(_mintAmount) 
      MintAmount(_mintAmount) {
          uint256 supply = totalSupply();
          require(!paused, "KEYS: The contract is paused");
          require(msg.sender != owner(), "KEYS: Owner cannot mint in this phase");
          require(phase == SalePhase.OgMint, "KEYS: Not in OG mint phase");
          require(_mintAmount <= maxMintAmountOG, "KEYS: Max mint amount per session exceeded");
          require(totalOgMinted + _mintAmount <= oGSupply, "KEYS: OG mint is full or remains less than mintAmount");
          require(supply + _mintAmount <= maxSupply, "KEYS: Max NFT limit exceeded");

              if(onlyOG == true) {
                  require(isOG(msg.sender), "KEYS: User is not an OG");
                  uint256 ownerMintedCount = addressMintedBalance[msg.sender];
                  require(ownerMintedCount + _mintAmount <= maxMintAmountOG, "KEYS: Max NFT for OG address exceeded");
              }
        

          for (uint256 i = 1; i <= _mintAmount; i++) {
            addressMintedBalance[msg.sender]++;
            totalOgMinted++;
            emit Mint(msg.sender, supply + i);
            _safeMint(msg.sender, supply + i);
    }    
  }

      function publicMint(uint256 _mintAmount) public payable 
        SalePrice(_mintAmount) 
        MintAmount(_mintAmount) {
            uint256 supply = totalSupply();
            require(!paused, "KEYS: The contract is paused");
            // require(msg.sender != owner(), "KEYS: Owner cannot mint in this phase");
            require(_mintAmount <= maxMintAmountPublic, "KEYS: Max mint amount per session exceeded");
            require(phase == SalePhase.PublicSale, "KEYS: Not in Public mint phase");
            require(totalPublicMinted + _mintAmount <= publicMintSupply, "KEYS: Public mint is full, or less than the remaining PublicSupply");
            require(supply + _mintAmount <= maxSupply, "KEYS: Max NFT limit exceeded");

            if (msg.sender != owner()) {
                  uint256 ownerMintedPublicCount = addressMintedPublicBalance[msg.sender];
                  require(ownerMintedPublicCount + _mintAmount <= maxMintAmountPublic, "KEYS: Max NFT for Public mint exceeded");
                }

            for (uint256 i = 1; i <= _mintAmount; i++) {
              addressMintedBalance[msg.sender]++;
              addressMintedPublicBalance[msg.sender]++;
              totalPublicMinted++;
              emit Mint(msg.sender, supply + i);
              _safeMint(msg.sender, supply + i);
        }
      }

      function devReserveTokens(uint256 _mintAmount) public 
        onlyOwner
      {
        uint256 supply = totalSupply();
            if(msg.sender == owner()) {
        require
            (
            _mintAmount + teamTokensMinted <= maxTeamMint,
          "KEYS:Exceeds the reserved supply of team tokens"
                );
            }
        for (uint256 i = 1; i <= _mintAmount; i++) {
          addressMintedBalance[msg.sender]++;
                teamTokensMinted++;
                emit Mint(msg.sender, supply + i);
                _safeMint(msg.sender, supply + i);
        }

      }

  function isWhitelisted(address _user) public view returns (bool) {
    for (uint i = 0; i < whitelistedAddresses.length; i++) {
      if (whitelistedAddresses[i] == _user) {
          return true;
      }
    }
    return false;
  }

  function isOG(address _user) public view returns (bool) {
    for (uint i = 0; i < addressOfOG.length; i++) {
      if (addressOfOG[i] == _user) {
          return true;
      }
    }
    return false;
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    if(revealed == false) {
        return notRevealedUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only ADMIN
  function reveal() public onlyOwner {
      revealed = true;
  }
  
  
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  function enterPhase(SalePhase phase_) external onlyOwner {
		phase = phase_;
	}


  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }
  
  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedUri = _notRevealedURI;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
  
  function setOnlyWhitelisted(bool _state) public onlyOwner {
    onlyWhitelisted = _state;
  }
  
  function whitelistUsers(address[] calldata _users) public onlyOwner {
    delete whitelistedAddresses;
    whitelistedAddresses = _users;
  }

  function OGUsers(address[] calldata _users) public onlyOwner {
    delete addressOfOG;
    addressOfOG = _users;
  }
 
  function withdraw() public payable onlyOwner {
    (bool success, ) = payable(owner()).call{value: address(this).balance}("");
    require(success);
  }
}