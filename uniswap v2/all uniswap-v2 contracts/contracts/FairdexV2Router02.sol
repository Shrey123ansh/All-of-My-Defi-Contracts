pragma solidity ^0.8.20;

import "./interfaces/IFairdexV2Factory.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IFairdexV2Router02.sol";
import "./libraries/FairdexV2Library.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWUSDC.sol";

contract FairdexV2Router02 is IFairdexV2Router02 {
    address public immutable factory;
    address public immutable WUSDC;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "FairdexV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WUSDC) {
        factory = _factory;
        WUSDC = _WUSDC;
    }

    receive() external payable {
        assert(msg.sender == WUSDC);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IFairdexV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IFairdexV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = FairdexV2Library.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = FairdexV2Library.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "FairdexV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = FairdexV2Library.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "FairdexV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint amountA, uint amountB, uint liquidity)
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = FairdexV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IFairdexV2Pair(pair).mint(to);
    }

    function addLiquidityUSDC(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountUSDCMin,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint amountToken, uint amountUSDC, uint liquidity)
    {
        (amountToken, amountUSDC) = _addLiquidity(
            token,
            WUSDC,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountUSDCMin
        );
        address pair = FairdexV2Library.pairFor(factory, token, WUSDC);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWUSDC(WUSDC).deposit{value: amountUSDC}();
        assert(IWUSDC(WUSDC).transfer(pair, amountUSDC));
        liquidity = IFairdexV2Pair(pair).mint(to);
        // refund dust USDC, if any
        if (msg.value > amountUSDC)
            TransferHelper.safeTransferUSDC(msg.sender, msg.value - amountUSDC);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint amountA, uint amountB)
    {
        address pair = FairdexV2Library.pairFor(factory, tokenA, tokenB);
        IFairdexV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IFairdexV2Pair(pair).burn(to);
        (address token0, ) = FairdexV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(
            amountA >= amountAMin,
            "FairdexV2Router: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "FairdexV2Router: INSUFFICIENT_B_AMOUNT"
        );
    }

    function removeLiquidityUSDC(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountUSDCMin,
        address to,
        uint deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint amountToken, uint amountUSDC)
    {
        (amountToken, amountUSDC) = removeLiquidity(
            token,
            WUSDC,
            liquidity,
            amountTokenMin,
            amountUSDCMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWUSDC(WUSDC).withdraw(amountUSDC);
        TransferHelper.safeTransferUSDC(to, amountUSDC);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = FairdexV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? type(uint256).max : liquidity;
        IFairdexV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityUSDCWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountUSDCMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountToken, uint amountUSDC) {
        address pair = FairdexV2Library.pairFor(factory, token, WUSDC);
        uint value = approveMax ? type(uint256).max : liquidity;
        IFairdexV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountUSDC) = removeLiquidityUSDC(
            token,
            liquidity,
            amountTokenMin,
            amountUSDCMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityUSDCSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountUSDCMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountUSDC) {
        (, amountUSDC) = removeLiquidity(
            token,
            WUSDC,
            liquidity,
            amountTokenMin,
            amountUSDCMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IERC20(token).balanceOf(address(this))
        );
        IWUSDC(WUSDC).withdraw(amountUSDC);
        TransferHelper.safeTransferUSDC(to, amountUSDC);
    }

    function removeLiquidityUSDCWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountUSDCMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint amountUSDC) {
        address pair = FairdexV2Library.pairFor(factory, token, WUSDC);
        uint value = approveMax ? type(uint256).max : liquidity;
        IFairdexV2Pair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountUSDC = removeLiquidityUSDCSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountUSDCMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FairdexV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOut)
                : (amountOut, uint(0));
            address to = i < path.length - 2
                ? FairdexV2Library.pairFor(factory, output, path[i + 2])
                : _to;
            IFairdexV2Pair(FairdexV2Library.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        amounts = FairdexV2Library.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "FairdexV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FairdexV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        amounts = FairdexV2Library.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "FairdexV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FairdexV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactUSDCForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WUSDC, "FairdexV2Router: INVALID_PATH");
        amounts = FairdexV2Library.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "FairdexV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWUSDC(WUSDC).deposit{value: amounts[0]}();
        assert(
            IWUSDC(WUSDC).transfer(
                FairdexV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactUSDC(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(
            path[path.length - 1] == WUSDC,
            "FairdexV2Router: INVALID_PATH"
        );
        amounts = FairdexV2Library.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "FairdexV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FairdexV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWUSDC(WUSDC).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferUSDC(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForUSDC(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(
            path[path.length - 1] == WUSDC,
            "FairdexV2Router: INVALID_PATH"
        );
        amounts = FairdexV2Library.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "FairdexV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FairdexV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWUSDC(WUSDC).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferUSDC(to, amounts[amounts.length - 1]);
    }

    function swapUSDCForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WUSDC, "FairdexV2Router: INVALID_PATH");
        amounts = FairdexV2Library.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= msg.value,
            "FairdexV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        IWUSDC(WUSDC).deposit{value: amounts[0]}();
        assert(
            IWUSDC(WUSDC).transfer(
                FairdexV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
        // refund dust USDC, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferUSDC(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FairdexV2Library.sortTokens(input, output);
            IFairdexV2Pair pair = IFairdexV2Pair(
                FairdexV2Library.pairFor(factory, input, output)
            );
            uint amountInput;
            uint amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1, ) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput =
                    IERC20(input).balanceOf(address(pair)) -
                    (reserveInput);
                amountOutput = FairdexV2Library.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOutput)
                : (amountOutput, uint(0));
            address to = i < path.length - 2
                ? FairdexV2Library.pairFor(factory, output, path[i + 2])
                : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FairdexV2Library.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - (balanceBefore) >=
                amountOutMin,
            "FairdexV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactUSDCForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WUSDC, "FairdexV2Router: INVALID_PATH");
        uint amountIn = msg.value;
        IWUSDC(WUSDC).deposit{value: amountIn}();
        assert(
            IWUSDC(WUSDC).transfer(
                FairdexV2Library.pairFor(factory, path[0], path[1]),
                amountIn
            )
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - (balanceBefore) >=
                amountOutMin,
            "FairdexV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForUSDCSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        require(
            path[path.length - 1] == WUSDC,
            "FairdexV2Router: INVALID_PATH"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FairdexV2Library.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WUSDC).balanceOf(address(this));
        require(
            amountOut >= amountOutMin,
            "FairdexV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWUSDC(WUSDC).withdraw(amountOut);
        TransferHelper.safeTransferUSDC(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual override returns (uint amountB) {
        return FairdexV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountOut) {
        return FairdexV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountIn) {
        return FairdexV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return FairdexV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts) {
        return FairdexV2Library.getAmountsIn(factory, amountOut, path);
    }
}
