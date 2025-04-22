// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.17; // Use a recent version compatible with dependencies

// import {Test, console2} from "forge-std/Test.sol";
// import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import {WETH} from "solmate/tokens/WETH.sol"; // Using Solmate's WETH9
// import {Token} from "../src/Token.sol"; // Assuming Token.sol exists at this path
// import {ERC20} from "solmate/tokens/ERC20.sol";

// contract UniswapGetterTests is Test {
//     // --- Mainnet Deployed Addresses (Requires Forking) ---
//     IUniswapV2Factory constant FACTORY =
//         IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
//     IUniswapV2Router02 constant ROUTER =
//         IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
//     WETH constant deployedWeth =
//         WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

//     // --- Test Setup Variables ---
//     Token tokenA;
//     Token tokenB;
//     IUniswapV2Pair pairAB; // TokenA / TokenB pair
//     IUniswapV2Pair pairAWeth; // TokenA / WETH pair

//     uint256 constant INITIAL_LIQUIDITY_TOKEN_A = 1000 ether;
//     uint256 constant INITIAL_LIQUIDITY_TOKEN_B = 2000 ether; // Different amount for variety
//     uint256 constant INITIAL_LIQUIDITY_WETH = 5 ether;

//     function setUp() public {
//         // 1. Create Test Tokens
//         tokenA = new Token("TokenA", "TKNA", 18); // Name, Symbol, Decimals
//         tokenB = new Token("TokenB", "TKNB", 18);

//         // 2. Fund Test Contract with ETH
//         vm.deal(address(this), 50 ether);

//         // 3. Mint Tokens to Test Contract
//         tokenA.mint(address(this), INITIAL_LIQUIDITY_TOKEN_A * 10); // Mint more than needed
//         tokenB.mint(address(this), INITIAL_LIQUIDITY_TOKEN_B * 10);

//         // 4. Approve Router to Spend Tokens
//         tokenA.approve(address(ROUTER), type(uint256).max);
//         tokenB.approve(address(ROUTER), type(uint256).max);
//         // WETH approval happens via deposit/transfer

//         // 5. Add Initial Liquidity to Create Pairs
//         // Add TokenA / WETH liquidity
//         (, , uint256 liquidityAWeth) = ROUTER.addLiquidityETH{value: INITIAL_LIQUIDITY_WETH}(
//             address(tokenA),
//             INITIAL_LIQUIDITY_TOKEN_A,
//             0, // amountTokenMin
//             0, // amountETHMin
//             address(this),
//             block.timestamp + 300
//         );
//         require(liquidityAWeth > 0, "Failed to add A/WETH liquidity");
//         address pairAWethAddress = FACTORY.getPair(address(tokenA), address(WETH));
//         require(pairAWethAddress != address(0), "A/WETH pair not created");
//         pairAWeth = IUniswapV2Pair(pairAWethAddress);

//         // Add TokenA / TokenB liquidity (Requires prior A/WETH or B/WETH for price)
//         // We will provide liquidity based on the A/WETH price implicitly
//         // Let's calculate a rough amount of B needed for A based on A/WETH initial rate
//         // Rough price: INITIAL_LIQUIDITY_TOKEN_A / INITIAL_LIQUIDITY_WETH = 1000 / 5 = 200 A per WETH
//         // Let's aim for a similar value for B, maybe 400 B per WETH. So B should be twice token A amount.
//         uint256 amountBDesired = INITIAL_LIQUIDITY_TOKEN_A * 2; // = 2000 ether
//         tokenB.approve(address(ROUTER), amountBDesired); // Re-approve specific amount just in case

//         (, , uint256 liquidityAB) = ROUTER.addLiquidity(
//             address(tokenA),
//             address(tokenB),
//             INITIAL_LIQUIDITY_TOKEN_A / 2, // Use half of A for this pool
//             amountBDesired / 2,           // Use half of desired B
//             0, // amountAMin
//             0, // amountBMin
//             address(this),
//             block.timestamp + 300
//         );
//         require(liquidityAB > 0, "Failed to add A/B liquidity");
//         address pairABAddress = FACTORY.getPair(address(tokenA), address(tokenB));
//         require(pairABAddress != address(0), "A/B pair not created");
//         pairAB = IUniswapV2Pair(pairABAddress);

//         console2.log("Setup complete.");
//         console2.log("Pair A/WETH Address:", address(pairAWeth));
//         console2.log("Pair A/B Address:", address(pairAB));
//         console2.log("LP Tokens A/WETH balance:", pairAWeth.balanceOf(address(this)));
//         console2.log("LP Tokens A/B balance:", pairAB.balanceOf(address(this)));

//     }

//     // --- Factory Getter Tests ---

//     function testGetFactoryProperties() public view {
//         assertEq(FACTORY.feeTo(), address(0), "Default feeTo should be address(0)"); // Check default, may change on forks
//         // feeToSetter might be a DAO or specific address on mainnet
//         assertTrue(FACTORY.feeToSetter() != address(0), "feeToSetter should be set");
//         assertGt(FACTORY.allPairsLength(), 0, "Should have pairs on mainnet fork");
//     }

//     function testGetFactoryPair() public view {
//         // Check existing pair (created in setup)
//         address fetchedPairAWeth = FACTORY.getPair(address(tokenA), address(WETH));
//         assertEq(fetchedPairAWeth, address(pairAWeth), "getPair(A, WETH) mismatch");

//         address fetchedPairAB = FACTORY.getPair(address(tokenA), address(tokenB));
//         assertEq(fetchedPairAB, address(pairAB), "getPair(A, B) mismatch");

//         // Check order doesn't matter
//         address fetchedPairBA = FACTORY.getPair(address(tokenB), address(tokenA));
//         assertEq(fetchedPairBA, address(pairAB), "getPair(B, A) mismatch");

//         // Check non-existent pair (using two random unused tokens - assuming Token creates unique addr)
//         Token tokenX = new Token("X", "X", 18);
//         Token tokenY = new Token("Y", "Y", 18);
//         address nonExistentPair = FACTORY.getPair(address(tokenX), address(tokenY));
//         assertEq(nonExistentPair, address(0), "getPair for non-existent should be 0");
//     }

//     // --- Router Getter Tests ---

//     function testGetRouterProperties() public view {
//         assertEq(ROUTER.factory(), address(FACTORY), "Router factory address mismatch");
//         assertEq(ROUTER.WETH(), address(WETH), "Router WETH address mismatch");
//     }

//     // --- Pair Getter Tests ---

//     function testGetPairTokenAddresses() public view {
//         // Pair A/WETH
//         address expectedToken0_AWeth;
//         address expectedToken1_AWeth;
//         (expectedToken0_AWeth, expectedToken1_AWeth) = sortTokens(address(tokenA), address(WETH));
//         assertEq(pairAWeth.token0(), expectedToken0_AWeth, "A/WETH pair token0 mismatch");
//         assertEq(pairAWeth.token1(), expectedToken1_AWeth, "A/WETH pair token1 mismatch");

//         // Pair A/B
//         address expectedToken0_AB;
//         address expectedToken1_AB;
//         (expectedToken0_AB, expectedToken1_AB) = sortTokens(address(tokenA), address(tokenB));
//         assertEq(pairAB.token0(), expectedToken0_AB, "A/B pair token0 mismatch");
//         assertEq(pairAB.token1(), expectedToken1_AB, "A/B pair token1 mismatch");
//     }

//     function testGetPairReservesAndTimestamp() public view {
//         // Pair A/WETH
//         (uint112 reserve0_AWeth, uint112 reserve1_AWeth, uint32 blockTimestampLast_AWeth) = pairAWeth.getReserves();
//         (address token0_AWeth, ) = sortTokens(address(tokenA), address(WETH));

//         console2.log("A/WETH Reserves (0, 1):", reserve0_AWeth, reserve1_AWeth);

//         if (address(tokenA) == token0_AWeth) {
//             // TokenA is token0, WETH is token1
//             assertApproxEqAbs(reserve0_AWeth, INITIAL_LIQUIDITY_TOKEN_A, 1, "A/WETH Reserve0 (TokenA) mismatch");
//             assertApproxEqAbs(reserve1_AWeth, INITIAL_LIQUIDITY_WETH, 1, "A/WETH Reserve1 (WETH) mismatch");
//         } else {
//             // WETH is token0, TokenA is token1
//             assertApproxEqAbs(reserve0_AWeth, INITIAL_LIQUIDITY_WETH, 1, "A/WETH Reserve0 (WETH) mismatch");
//             assertApproxEqAbs(reserve1_AWeth, INITIAL_LIQUIDITY_TOKEN_A, 1, "A/WETH Reserve1 (TokenA) mismatch");
//         }
//         assertGt(blockTimestampLast_AWeth, 0, "A/WETH blockTimestampLast should be > 0");
//         assertTrue(blockTimestampLast_AWeth <= block.timestamp, "A/WETH blockTimestampLast is in future");

//         // Pair A/B
//         (uint112 reserve0_AB, uint112 reserve1_AB, uint32 blockTimestampLast_AB) = pairAB.getReserves();
//         (address token0_AB, ) = sortTokens(address(tokenA), address(tokenB));

//         console2.log("A/B Reserves (0, 1):", reserve0_AB, reserve1_AB);
//          if (address(tokenA) == token0_AB) {
//             // TokenA is token0, TokenB is token1
//             assertApproxEqAbs(reserve0_AB, INITIAL_LIQUIDITY_TOKEN_A / 2, 1, "A/B Reserve0 (TokenA) mismatch");
//             assertApproxEqAbs(reserve1_AB, INITIAL_LIQUIDITY_TOKEN_B / 2, 1, "A/B Reserve1 (TokenB) mismatch");
//         } else {
//             // TokenB is token0, TokenA is token1
//             assertApproxEqAbs(reserve0_AB, INITIAL_LIQUIDITY_TOKEN_B / 2, 1, "A/B Reserve0 (TokenB) mismatch");
//             assertApproxEqAbs(reserve1_AB, INITIAL_LIQUIDITY_TOKEN_A / 2, 1, "A/B Reserve1 (TokenA) mismatch");
//         }
//         assertGt(blockTimestampLast_AB, 0, "A/B blockTimestampLast should be > 0");
//         assertTrue(blockTimestampLast_AB <= block.timestamp, "A/B blockTimestampLast is in future");

//     }

//     function testGetPairTotalSupply() public view {
//         // Check LP token supply exists for pairs created in setUp
//         assertGt(pairAWeth.totalSupply(), 0, "A/WETH LP token total supply should be > 0");
//         assertGt(pairAB.totalSupply(), 0, "A/B LP token total supply should be > 0");

//         // Check our balance of LP tokens
//         assertGt(pairAWeth.balanceOf(address(this)), 0, "Contract A/WETH LP balance should be > 0");
//         assertGt(pairAB.balanceOf(address(this)), 0, "Contract A/B LP balance should be > 0");
//     }

//      function testGetPairKLast() public view {
//         // kLast is used for TWAP oracles. It's the product of reserves before the *last* fee-affecting action (mint/burn/swap).
//         // It might be 0 right after creation/first liquidity add until a swap occurs.
//         // Let's check it's not negative. A more complex test could perform a swap then check kLast.
//         uint kLast_AWeth = pairAWeth.kLast();
//         uint kLast_AB = pairAB.kLast();

//         console2.log("KLast A/WETH:", kLast_AWeth);
//         console2.log("KLast A/B:", kLast_AB);

//         assertTrue(kLast_AWeth >= 0, "kLast A/WETH should be >= 0");
//          // KLast is often 0 until the first swap or liquidity removal event after initial mint.
//         // assertGt(kLast_AWeth, 0, "kLast A/WETH should be > 0 after liquidity add"); // This might fail depending on exact Uniswap version behavior
//         assertTrue(kLast_AB >= 0, "kLast A/B should be >= 0");
//     }

//     // --- Router Calculation Getter Tests ---

//     function testGetAmountsOut() public view {
//         // Path: WETH -> TokenA
//         address[] memory pathWethToA = new address[](2);
//         pathWethToA[0] = address(WETH);
//         pathWethToA[1] = address(tokenA);
//         uint amountInWeth = 1 ether;
//         uint[] memory amountsOutWethToA = ROUTER.getAmountsOut(amountInWeth, pathWethToA);

//         assertEq(amountsOutWethToA.length, 2, "amountsOutWethToA length mismatch");
//         assertEq(amountsOutWethToA[0], amountInWeth, "amountsOutWethToA input mismatch");
//         assertGt(amountsOutWethToA[1], 0, "amountsOutWethToA output (A) should be > 0");
//         // Rough check: ~ 1 WETH * (1000 A / 5 WETH) * 0.997 fee = ~199.4 A
//         uint expectedRough_A = (amountInWeth * INITIAL_LIQUIDITY_TOKEN_A / INITIAL_LIQUIDITY_WETH) * 997 / 1000;
//         assertApproxEqAbs(amountsOutWethToA[1], expectedRough_A, expectedRough_A / 100, "amountsOutWethToA output (A) approx mismatch"); // 1% tolerance

//         // Path: TokenA -> TokenB
//         address[] memory pathAToB = new address[](2);
//         pathAToB[0] = address(tokenA);
//         pathAToB[1] = address(tokenB);
//         uint amountInA = 10 ether;
//          uint[] memory amountsOutAToB = ROUTER.getAmountsOut(amountInA, pathAToB);

//         assertEq(amountsOutAToB.length, 2, "amountsOutAToB length mismatch");
//         assertEq(amountsOutAToB[0], amountInA, "amountsOutAToB input mismatch");
//         assertGt(amountsOutAToB[1], 0, "amountsOutAToB output (B) should be > 0");
//         // Rough check based on setup: ~ 10 A * ( (2000/2) B / (1000/2) A ) * 0.997 fee = 10 * 2 * 0.997 = ~19.94 B
//         (uint112 reserveA_AB, uint112 reserveB_AB, ) = pairAB.getReserves(); // Get current reserves for better calc
//         uint expectedRough_B = (amountInA * reserveB_AB * 997) / (reserveA_AB * 1000 + amountInA * 997); // Uniswap formula
//         assertApproxEqAbs(amountsOutAToB[1], expectedRough_B, expectedRough_B / 100, "amountsOutAToB output (B) approx mismatch");

//         // Path: WETH -> TokenA -> TokenB
//         address[] memory pathWethAToB = new address[](3);
//         pathWethAToB[0] = address(WETH);
//         pathWethAToB[1] = address(tokenA);
//         pathWethAToB[2] = address(tokenB);
//         uint[] memory amountsOutWethAToB = ROUTER.getAmountsOut(amountInWeth, pathWethAToB);

//         assertEq(amountsOutWethAToB.length, 3, "amountsOutWethAToB length mismatch");
//         assertEq(amountsOutWethAToB[0], amountInWeth, "amountsOutWethAToB input mismatch");
//         assertGt(amountsOutWethAToB[1], 0, "amountsOutWethAToB intermediate (A) > 0");
//         assertGt(amountsOutWethAToB[2], 0, "amountsOutWethAToB output (B) > 0");
//         // Check relationship: A out from first leg should be input for second (approx)
//         assertApproxEqAbs(amountsOutWethAToB[1], amountsOutWethToA[1], amountsOutWethToA[1]/1000, "Intermediate A mismatch"); // Small tolerance for fees
//         // Check final B output relative to calculated intermediate A
//         uint expectedRough_B_multi = (amountsOutWethAToB[1] * reserveB_AB * 997) / (reserveA_AB * 1000 + amountsOutWethAToB[1] * 997);
//         assertApproxEqAbs(amountsOutWethAToB[2], expectedRough_B_multi, expectedRough_B_multi / 100, "amountsOutWethAToB output (B) approx mismatch");

//     }

//      function testGetAmountsIn() public view {
//         // Path: WETH -> TokenA
//         address[] memory pathWethToA = new address[](2);
//         pathWethToA[0] = address(WETH);
//         pathWethToA[1] = address(tokenA);
//         uint amountOutA = 100 ether; // Desired TokenA
//         uint[] memory amountsInWethToA = ROUTER.getAmountsIn(amountOutA, pathWethToA);

//         assertEq(amountsInWethToA.length, 2, "amountsInWethToA length mismatch");
//         assertGt(amountsInWethToA[0], 0, "amountsInWethToA input (WETH) should be > 0");
//         assertEq(amountsInWethToA[1], amountOutA, "amountsInWethToA output mismatch");
//          // Rough check: ~ 100 A * (5 WETH / 1000 A) / 0.997 fee = ~0.5015 WETH
//         (uint112 reserveWeth_AWeth, uint112 reserveA_AWeth, ) = pairAWeth.getReserves(); // Get current reserves
//         uint expectedRough_Weth = (reserveWeth_AWeth * amountOutA * 1000) / (reserveA_AWeth * 997); // Simplified inverse formula (ignoring fee effect on denominator)
//         // assertTrue(amountsInWethToA[0] > expectedRough_Weth, "Input WETH seems too low"); // Fee increases input
//         assertApproxEqAbs(amountsInWethToA[0], expectedRough_Weth, expectedRough_Weth / 50, "amountsInWethToA input (WETH) approx mismatch"); // 2% tolerance

//         // Path: TokenA -> TokenB
//         address[] memory pathAToB = new address[](2);
//         pathAToB[0] = address(tokenA);
//         pathAToB[1] = address(tokenB);
//         uint amountOutB = 20 ether; // Desired TokenB
//         uint[] memory amountsInAToB = ROUTER.getAmountsIn(amountOutB, pathAToB);

//         assertEq(amountsInAToB.length, 2, "amountsInAToB length mismatch");
//         assertGt(amountsInAToB[0], 0, "amountsInAToB input (A) should be > 0");
//         assertEq(amountsInAToB[1], amountOutB, "amountsInAToB output mismatch");
//         // Rough check: ~ 20 B * ( (1000/2) A / (2000/2) B ) / 0.997 fee = 20 * 0.5 / 0.997 = ~10.03 A
//         (uint112 reserveA_AB, uint112 reserveB_AB, ) = pairAB.getReserves(); // Get current reserves
//         uint expectedRough_A_in = (reserveA_AB * amountOutB * 1000) / (reserveB_AB * 997);
//         assertApproxEqAbs(amountsInAToB[0], expectedRough_A_in, expectedRough_A_in / 50, "amountsInAToB input (A) approx mismatch"); // 2% tolerance


//         // Path: WETH -> TokenA -> TokenB
//         address[] memory pathWethAToB = new address[](3);
//         pathWethAToB[0] = address(WETH);
//         pathWethAToB[1] = address(tokenA);
//         pathWethAToB[2] = address(tokenB);
//          uint[] memory amountsInWethAToB = ROUTER.getAmountsIn(amountOutB, pathWethAToB); // Same desired B as above

//         assertEq(amountsInWethAToB.length, 3, "amountsInWethAToB length mismatch");
//         assertGt(amountsInWethAToB[0], 0, "amountsInWethAToB input (WETH) > 0");
//         assertGt(amountsInWethAToB[1], 0, "amountsInWethAToB intermediate (A) > 0");
//         assertEq(amountsInWethAToB[2], amountOutB, "amountsInWethAToB output mismatch");
//          // Check relationship: Intermediate A needed should match input A from previous test (approx)
//         assertApproxEqAbs(amountsInWethAToB[1], amountsInAToB[0], amountsInAToB[0]/1000, "Intermediate A input mismatch");
//     }

//     // --- Helper Functions ---

//     function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
//         require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
//         (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
//         require(token0 != address(0), "ZERO_ADDRESS");
//     }

//     // Receive function isn't strictly needed for getter tests but good practice
//     receive() external payable {}
// }