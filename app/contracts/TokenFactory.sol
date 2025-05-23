// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


import "./Token.sol";
import "hardhat/console.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

contract TokenFactory { 


    struct memeToken {
        string name;
        string symbol;
        string description;
        string tokenImageUrl;
        uint fundingRaised;             // minimum funding goal is 24 ether after which the token will be listed on uniswap
        address tokenAddress;
        address creatorAddress;
    }

    // mapping of token address to memeToken struct
    // this will be used to get the details of the token
    address[] public memeTokenAddresses;

    mapping(address => memeToken) public addressToMemeTokenMapping;
    
    // "Fee" for the platform
    // These values are set to avoid precision loss in calculations
    uint constant MEMETOKEN_CREATION_PLATFORM_FEE = 0.0001 ether;
    uint constant MEMECOIN_FUNDING_DEADLINE_DURATION = 10 days;
    uint constant MEMECOIN_FUNDING_GOAL = 24 ether;

    address constant UNISWAP_V2_FACTORY_ADDRESS = 0xF62c03E08ada871A0bEb309762E260a7a6a880E6;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;


    // Constants for the bonding curve
    // These values are set to avoid precision loss in calculations
    uint constant DECIMALS = 10 ** 18;
    uint constant MAX_SUPPLY = 1000000 * DECIMALS;
    uint constant INIT_SUPPLY = 20 * MAX_SUPPLY / 100;  // 20% of max supply

    uint256 public constant INITIAL_PRICE = 30000000000000;  // Initial price in wei (P0), 3.00 * 10^13
    uint256 public constant K = 8 * 10**15;  // Growth rate (k), scaled to avoid precision loss (0.01 * 10^18)






    // Function to calculate the cost in wei for purchasing `tokensToBuy` starting from `currentSupply`
    function calculateCost(uint256 currentSupply, uint256 tokensToBuy) public pure returns (uint256) {
        
            // Calculate the exponent parts scaled to avoid precision loss
        uint256 exponent1 = (K * (currentSupply + tokensToBuy)) / 10**18;
        uint256 exponent2 = (K * currentSupply) / 10**18;

        // Calculate e^(kx) using the exp function
        uint256 exp1 = exp(exponent1);
        uint256 exp2 = exp(exponent2);

        // Cost formula: (P0 / k) * (e^(k * (currentSupply + tokensToBuy)) - e^(k * currentSupply))
        // We use (P0 * 10^18) / k to keep the division safe from zero
        uint256 cost = (INITIAL_PRICE * 10**18 * (exp1 - exp2)) / K;  // Adjust for k scaling without dividing by zero
        return cost;
    }

    // Improved helper function to calculate e^x for larger x using a Taylor series approximation
    function exp(uint256 x) internal pure returns (uint256) {
        uint256 sum = 10**18;  // Start with 1 * 10^18 for precision
        uint256 term = 10**18;  // Initial term = 1 * 10^18
        uint256 xPower = x;  // Initial power of x
        
        for (uint256 i = 1; i <= 20; i++) {  // Increase iterations for better accuracy
            term = (term * xPower) / (i * 10**18);  // x^i / i!
            sum += term;

            // Prevent overflow and unnecessary calculations
            if (term < 1) break;
        }

        return sum;
    }





    // 1. Create a new meme token + deploy the contract
    function createMemeToken(string memory name, string memory symbol, string memory imageUrl, string memory description) public payable returns(address) {

        //should deploy the meme token, mint the initial supply to the token factory contract

        // check if the user create enough tokens than the gas fee
        require(msg.value>= MEMETOKEN_CREATION_PLATFORM_FEE, "fee not paid for memetoken creation");
        Token ct = new Token(name, symbol, INIT_SUPPLY);
        address memeTokenAddress = address(ct);
        memeToken memory newlyCreatedToken = memeToken(name, symbol, description, imageUrl, 0, memeTokenAddress, msg.sender);   
        // 0-> funding raised

        memeTokenAddresses.push(memeTokenAddress);

        // console.log("Token address is ", memeTokenAddress);
        // console.log("Token name is ", name);
        // console.log("Token symbol is ", symbol);
        // console.log("Token description is ", description);
        // console.log("Token image url is ", imageUrl);
        // console.log("Funding raised is ", 0);

        addressToMemeTokenMapping[memeTokenAddress] = newlyCreatedToken;
        return memeTokenAddress;
    }

    function getAllMemeTokens() public view returns(memeToken[] memory) {
        memeToken[] memory allTokens = new memeToken[](memeTokenAddresses.length);
        for (uint i = 0; i < memeTokenAddresses.length; i++) {
            allTokens[i] = addressToMemeTokenMapping[memeTokenAddresses[i]];
        }
        return allTokens;
    }

    // 2. Buy the meme token
    function buyMemeToken(address memeTokenAddress, uint tokenQty) public payable returns(uint) {

        //check if memecoin is listed on our platform
        require(addressToMemeTokenMapping[memeTokenAddress].tokenAddress!=address(0), "Token is not listed");
        
        memeToken storage listedToken = addressToMemeTokenMapping[memeTokenAddress];


        Token memeTokenCt = Token(memeTokenAddress);

        // check to ensure funding goal is not met
        require(listedToken.fundingRaised <= MEMECOIN_FUNDING_GOAL, "Funding has already been raised");


        // check to ensure there is enough supply to facilitate the purchase
        uint currentSupply = memeTokenCt.totalSupply();
        console.log("Current supply of token is ", currentSupply);
        console.log("Max supply of token is ", MAX_SUPPLY);
        uint available_qty = MAX_SUPPLY - currentSupply;
        console.log("Qty available for purchase ",available_qty);


        uint scaled_available_qty = available_qty / DECIMALS;
        uint tokenQty_scaled = tokenQty * DECIMALS;

        require(tokenQty <= scaled_available_qty, "Not enough available supply");

        // calculate the cost for purchasing tokenQty tokens as per the exponential bonding curve formula
        uint currentSupplyScaled = (currentSupply - INIT_SUPPLY) / DECIMALS;
        uint requiredEth = calculateCost(currentSupplyScaled, tokenQty);

        console.log("ETH required for purchasing meme tokens is ",requiredEth);

        // check if user has sent correct value of eth to facilitate this purchase
        require(msg.value >= requiredEth, "Incorrect value of ETH sent");

        // Incerement the funding
        listedToken.fundingRaised+= msg.value;

        if(listedToken.fundingRaised >= MEMECOIN_FUNDING_GOAL){
            // create liquidity pool
            address pool = _createLiquidityPool(memeTokenAddress);
            console.log("Pool address ", pool);

            // provide liquidity
            uint tokenAmount = INIT_SUPPLY;
            uint ethAmount = listedToken.fundingRaised;
            uint liquidity = _provideLiquidity(memeTokenAddress, tokenAmount, ethAmount);
            console.log("UNiswap provided liquidty ", liquidity);

            // burn lp token
            _burnLpTokens(pool, liquidity);

        }

        // mint the tokens
        memeTokenCt.mint(tokenQty_scaled, msg.sender);

        console.log("User balance of the tokens is ", memeTokenCt.balanceOf(msg.sender));

        console.log("New available qty ", MAX_SUPPLY - memeTokenCt.totalSupply());

        return 1;
    }

    // 3. Create a liquidity pool for the token (uniswap v2) goal is to create a pool for the token and ETH
    function _createLiquidityPool(address memeTokenAddress) internal returns(address) {
        IUniswapV2Factory factory = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS);
        IUniswapV2Router01 router = IUniswapV2Router01(UNISWAP_V2_ROUTER_ADDRESS);
        address pair = factory.createPair(memeTokenAddress, router.WETH());
        return pair;
    }

    // 4. Provide liquidity to the pool
    // this function will be called when the funding goal is met
    function _provideLiquidity(address memeTokenAddress, uint tokenAmount, uint ethAmount) internal returns(uint){
        Token memeTokenCt = Token(memeTokenAddress);
        memeTokenCt.approve(UNISWAP_V2_ROUTER_ADDRESS, tokenAmount);
        IUniswapV2Router01 router = IUniswapV2Router01(UNISWAP_V2_ROUTER_ADDRESS);
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{
            value: ethAmount
        }(memeTokenAddress, tokenAmount, tokenAmount, ethAmount, address(this), block.timestamp);
        return liquidity;
    }


    // 5. Burn the LP tokens because we are not going to use them and this cause gas fees
    function _burnLpTokens(address pool, uint liquidity) internal returns(uint){
        IUniswapV2Pair uniswapv2pairct = IUniswapV2Pair(pool);
        uniswapv2pairct.transfer(address(0), liquidity);
        console.log("Uni v2 tokens burnt");
        return 1;
    }



}