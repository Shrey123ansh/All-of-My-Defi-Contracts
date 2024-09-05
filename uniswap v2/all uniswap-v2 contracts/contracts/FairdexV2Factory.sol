pragma solidity ^0.8.20;

import "./interfaces/IFairdexV2Factory.sol";
import "./FairdexV2Pair.sol";

contract FairdexV2Factory is IFairdexV2Factory {
    address public feeTo;
    address public feeToSetter;
    uint256 public nDev = 1;
    uint256 public dDev = 1;
    uint32 public devFee = 5; // uses 0.04% default from swap fee

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        require(tokenA != tokenB, "FairdexV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "FairdexV2: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "FairdexV2: PAIR_EXISTS"
        ); // single check is sufficient
        bytes memory bytecode = type(FairdexV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IFairdexV2Pair(pair).initialize(token0, token1, nDev, dDev, devFee);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "FairdexV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "FairdexV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function setPercentForAllPairs(uint256 _ndev, uint256 _ddev) external {
        require(msg.sender == feeToSetter, "FairdexV2: FORBIDDEN");
        nDev = _ndev;
        dDev = _ddev;
        for (uint256 i = 0; i < allPairs.length; i++) {
            FairdexV2Pair(allPairs[i]).setPercent(_ndev, _ddev);
        }
    }

    // Function to set dev fee for all pairs
    function setDevFeeForAllPairs(uint32 _devFee) external {
        require(msg.sender == feeToSetter, "FairdexV2: FORBIDDEN");
        require(_devFee <= 10000, "FairdexV2: FORBIDDEN_FEE");
        devFee = _devFee;
        for (uint256 i = 0; i < allPairs.length; i++) {
            FairdexV2Pair(allPairs[i]).setDevFee(_devFee);
        }
    }
}
