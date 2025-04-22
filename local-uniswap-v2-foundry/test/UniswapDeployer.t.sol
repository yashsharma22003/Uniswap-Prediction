// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >=0.8.5;

import {Test} from "forge-std/Test.sol";
import {UniswapDeployer} from "../script/UniswapDeployer.s.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {Token} from "../src/Token.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract UniswapTests is Test {
    IUniswapV2Factory factory =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    
    WETH deployedWeth =
        WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    
    IUniswapV2Router02 router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    
    Token token1;
    Token token2;
    IUniswapV2Pair pair;
    address pairAddress;
    uint256 constant INITIAL_LIQUIDITY_ETH = 10 ether;
    uint256 constant INITIAL_LIQUIDITY_TOKEN = 1000 ether;
    address constant RECIPIENT = address(0x123);

    function setUp() public {
        UniswapDeployer deployer = new UniswapDeployer();
        deployer.run();
        
        // Create test tokens
        token1 = new Token();
        token2 = new Token();
        
        // Approve router to spend tokens
        token1.approve(address(router), type(uint256).max);
        token2.approve(address(router), type(uint256).max);
        
        // Fund test address with ETH for operations
        vm.deal(address(this), 100 ether);
    }

    // Basic deployment tests
    function test_uniswapFactory() public view {
        assert(factory.feeToSetter() != address(0));
    }

    function test_wrappedEther() public view {
        assert(abi.encode(deployedWeth.name()).length > 0);
    }

    function test_deployedRouter() public view {
        assert(router.WETH() != address(0));
    }

    // Liquidity tests
    function test_addLiquidityETH() public {
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Get the pair address
        pairAddress = factory.getPair(address(token1), address(deployedWeth));
        pair = IUniswapV2Pair(pairAddress);
        
        // Verify results
        assertGt(amountToken, 0, "Token amount should be greater than 0");
        assertGt(amountETH, 0, "ETH amount should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");
        assertEq(pair.balanceOf(address(this)), liquidity, "Incorrect LP token balance");
    }
    
    function test_addLiquidityToken() public {
        // First add liquidity for token1 with ETH
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Then add liquidity for token2 with ETH
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token2),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Now add liquidity between token1 and token2
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(token1),
            address(token2),
            INITIAL_LIQUIDITY_TOKEN / 2,
            INITIAL_LIQUIDITY_TOKEN / 2,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Get the pair address
        pairAddress = factory.getPair(address(token1), address(token2));
        pair = IUniswapV2Pair(pairAddress);
        
        // Verify results
        assertGt(amountA, 0, "Token A amount should be greater than 0");
        assertGt(amountB, 0, "Token B amount should be greater than 0");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");
        assertEq(pair.balanceOf(address(this)), liquidity, "Incorrect LP token balance");
    }
    
    function test_removeLiquidityETH() public {
        // First add liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Get the pair address
        pairAddress = factory.getPair(address(token1), address(deployedWeth));
        pair = IUniswapV2Pair(pairAddress);
        
        // Approve router to spend LP tokens
        pair.approve(address(router), liquidity);
        
        // Record balances before
        uint256 ethBalanceBefore = address(this).balance;
        uint256 tokenBalanceBefore = token1.balanceOf(address(this));
        
        // Remove liquidity
        (uint256 tokenAmount, uint256 ethAmount) = router.removeLiquidityETH(
            address(token1),
            liquidity,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Verify results
        assertGt(tokenAmount, 0, "Token amount should be greater than 0");
        assertGt(ethAmount, 0, "ETH amount should be greater than 0");
        assertEq(address(this).balance - ethBalanceBefore, ethAmount, "ETH balance not increased correctly");
        assertEq(token1.balanceOf(address(this)) - tokenBalanceBefore, tokenAmount, "Token balance not increased correctly");
        assertEq(pair.balanceOf(address(this)), 0, "LP token balance should be 0");
    }
    
    // Swap tests
    function test_swapExactETHForTokens() public {
        // First add liquidity
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Create path for swap
        address[] memory path = new address[](2);
        path[0] = address(deployedWeth);
        path[1] = address(token1);
        
        // Record balance before
        uint256 tokenBalanceBefore = token1.balanceOf(address(this));
        
        // Execute swap
        uint256 swapAmount = 1 ether;
        uint256[] memory amounts = router.swapExactETHForTokens{value: swapAmount}(
            0, // Minimum output (0 for testing, use a real value in production)
            path,
            address(this),
            block.timestamp + 1000
        );
        
        // Verify results
        assertEq(amounts.length, 2, "Should return amounts for 2 tokens in path");
        assertEq(amounts[0], swapAmount, "Input amount mismatch");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");
        assertEq(token1.balanceOf(address(this)) - tokenBalanceBefore, amounts[1], "Token balance not increased correctly");
    }
    
    function test_swapExactTokensForETH() public {
        // First add liquidity
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Create path for swap
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(deployedWeth);
        
        // Record balance before
        uint256 ethBalanceBefore = address(this).balance;
        
        // Execute swap
        uint256 swapAmount = 10 ether;
        uint256[] memory amounts = router.swapExactTokensForETH(
            swapAmount,
            0, // Minimum output (0 for testing, use a real value in production)
            path,
            address(this),
            block.timestamp + 1000
        );
        
        // Verify results
        assertEq(amounts.length, 2, "Should return amounts for 2 tokens in path");
        assertEq(amounts[0], swapAmount, "Input amount mismatch");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");
        assertEq(address(this).balance - ethBalanceBefore, amounts[1], "ETH balance not increased correctly");
    }
    
    function test_swapExactTokensForTokens() public {
        // Add liquidity for first pair (token1-ETH)
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Add liquidity for second pair (token2-ETH)
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token2),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Create path for swap (token1 -> ETH -> token2)
        address[] memory path = new address[](3);
        path[0] = address(token1);
        path[1] = address(deployedWeth);
        path[2] = address(token2);
        
        // Record balance before
        uint256 token2BalanceBefore = token2.balanceOf(address(this));
        
        // Execute swap
        uint256 swapAmount = 10 ether;
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0, // Minimum output (0 for testing, use a real value in production)
            path,
            address(this),
            block.timestamp + 1000
        );
        
        // Verify results
        assertEq(amounts.length, 3, "Should return amounts for 3 tokens in path");
        assertEq(amounts[0], swapAmount, "Input amount mismatch");
        assertGt(amounts[2], 0, "Output amount should be greater than 0");
        assertEq(token2.balanceOf(address(this)) - token2BalanceBefore, amounts[2], "Token2 balance not increased correctly");
    }
    
    function test_swapTokensForExactETH() public {
        // First add liquidity
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Create path for swap
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(deployedWeth);
        
        // Record balance before
        uint256 ethBalanceBefore = address(this).balance;
        
        // Execute swap
        uint256 exactOutputAmount = 1 ether;
        uint256[] memory amounts = router.swapTokensForExactETH(
            exactOutputAmount,
            type(uint256).max, // Max input (unlimited for testing, use a real limit in production)
            path,
            address(this),
            block.timestamp + 1000
        );
        
        // Verify results
        assertEq(amounts.length, 2, "Should return amounts for 2 tokens in path");
        assertGt(amounts[0], 0, "Input amount should be greater than 0");
        assertEq(amounts[1], exactOutputAmount, "Output amount mismatch");
        assertEq(address(this).balance - ethBalanceBefore, exactOutputAmount, "ETH balance not increased correctly");
    }
    
    function test_swapWithDeadline() public {
        // First add liquidity
        router.addLiquidityETH{value: INITIAL_LIQUIDITY_ETH}(
            address(token1),
            INITIAL_LIQUIDITY_TOKEN,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );
        
        // Create path for swap
        address[] memory path = new address[](2);
        path[0] = address(deployedWeth);
        path[1] = address(token1);
        
        // Set timestamp to future
        vm.warp(block.timestamp + 2000);
        
        // Attempt swap with expired deadline
        uint256 swapAmount = 1 ether;
        
        // This should revert with EXPIRED error
        vm.expectRevert("UniswapV2Router: EXPIRED");
        router.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            address(this),
            block.timestamp - 1000 // Expired deadline
        );
    }
    
    
    // Helper function to sort token addresses like UniswapV2Library does
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
    
    // Receive function to allow contract to receive ETH
    receive() external payable {}
}