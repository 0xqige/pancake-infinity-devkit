// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import "forge-std/console.sol";

/**
 * @title StandardTestToken
 * @notice Standard ERC20 test token
 */
contract StandardTestToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol, decimals_) {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

/**
 * @title FeeOnTransferToken  
 * @notice Token that charges fees on transfer (similar to SAFEMOON)
 */
contract FeeOnTransferToken is ERC20 {
    uint256 public transferFeeRate = 100; // 1% = 100/10000
    address public feeRecipient;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol, decimals_) {
        feeRecipient = msg.sender;
        _mint(msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * transferFeeRate) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        if (fee > 0) {
            super.transfer(feeRecipient, fee);
        }
        return super.transfer(to, amountAfterFee);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * transferFeeRate) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        if (fee > 0) {
            super.transferFrom(from, feeRecipient, fee);
        }
        return super.transferFrom(from, to, amountAfterFee);
    }

    function setTransferFeeRate(uint256 newRate) external {
        require(newRate <= 1000, "Fee rate too high"); // Maximum 10%
        transferFeeRate = newRate;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title DeflationaryToken
 * @notice Deflationary token - burns a certain percentage of tokens on each transfer
 */
contract DeflationaryToken is ERC20 {
    uint256 public burnRate = 10; // 0.1% = 10/10000
    uint256 public totalBurned;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol, decimals_) {
        _mint(msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 burnAmount = (amount * burnRate) / 10000;
        uint256 transferAmount = amount - burnAmount;
        
        if (burnAmount > 0) {
            _burn(msg.sender, burnAmount);
            totalBurned += burnAmount;
        }
        
        return super.transfer(to, transferAmount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 burnAmount = (amount * burnRate) / 10000;
        uint256 transferAmount = amount - burnAmount;
        
        if (burnAmount > 0) {
            _burn(from, burnAmount);
            totalBurned += burnAmount;
        }
        
        return super.transferFrom(from, to, transferAmount);
    }

    function setBurnRate(uint256 newRate) external {
        require(newRate <= 500, "Burn rate too high"); // Maximum 5%
        burnRate = newRate;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title RebasingToken
 * @notice Rebasing token - balance adjusts dynamically based on rebase factor
 */
contract RebasingToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private _totalGons;
    uint256 private _gonsPerFragment;
    
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 10**6 * 10**18;
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _totalGons = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS / initialSupply;
        
        _gonBalances[msg.sender] = TOTAL_GONS;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function totalSupply() public view returns (uint256) {
        return _totalGons / _gonsPerFragment;
    }

    function balanceOf(address who) public view returns (uint256) {
        return _gonBalances[who] / _gonsPerFragment;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        uint256 gonValue = value * _gonsPerFragment;
        _gonBalances[msg.sender] -= gonValue;
        _gonBalances[to] += gonValue;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 gonValue = value * _gonsPerFragment;
        _gonBalances[from] -= gonValue;
        _gonBalances[to] += gonValue;
        
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        
        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function rebase(uint256 epoch, int256 supplyDelta) external returns (uint256) {
        if (supplyDelta == 0) {
            return totalSupply();
        }

        uint256 currentSupply = totalSupply();
        uint256 newSupply;
        
        if (supplyDelta < 0) {
            newSupply = currentSupply - uint256(-supplyDelta);
        } else {
            newSupply = currentSupply + uint256(supplyDelta);
        }

        if (newSupply > 0) {
            _gonsPerFragment = _totalGons / newSupply;
        }

        console.log("Rebase epoch:", epoch, "new supply:", newSupply);
        return newSupply;
    }

    function mint(address to, uint256 amount) external {
        uint256 gonAmount = amount * _gonsPerFragment;
        _gonBalances[to] += gonAmount;
        emit Transfer(address(0), to, amount);
    }
}

/**
 * @title NonStandardToken
 * @notice Non-standard ERC20 token - transfer function doesn't return bool value
 */
contract NonStandardToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // Note: This transfer function doesn't return bool value
    function transfer(address to, uint256 value) external {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
    }

    // Note: This transferFrom function also doesn't return bool value
    function transferFrom(address from, address to, uint256 value) external {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}

/**
 * @title MockWETH
 * @notice Mock WETH contract
 */
contract MockWETH is StandardTestToken {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor(uint256 initialSupply) 
        StandardTestToken("Wrapped Ether", "WETH", 18, initialSupply) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        require(balanceOf[msg.sender] >= wad, "Insufficient balance");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}