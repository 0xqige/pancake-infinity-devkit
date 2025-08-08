// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";

/**
 * @title WBNB (Wrapped BNB)
 * @notice WETH9风格的BNB包装合约
 * @dev 允许将原生BNB包装成ERC20代币WBNB
 */
contract WBNB {
    string public name = "Wrapped BNB";
    string public symbol = "WBNB";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice 接收BNB并铸造等量WBNB
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice 接收BNB的回退函数
     */
    fallback() external payable {
        deposit();
    }

    /**
     * @notice 存入BNB并获得WBNB
     */
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        console.log("WBNB: Deposited", msg.value / 1e18, "BNB from", msg.sender);
    }

    /**
     * @notice 提取BNB，销毁WBNB
     * @param wad 提取数量
     */
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "WBNB: insufficient balance");
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
        console.log("WBNB: Withdrew", wad / 1e18, "BNB to", msg.sender);
    }

    /**
     * @notice 获取总供应量（等于合约中的BNB余额）
     */
    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice 批准代币转账
     */
    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice 转账WBNB
     */
    function transfer(address to, uint256 value) public returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    /**
     * @notice 授权转账WBNB
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "WBNB: insufficient balance");

        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= value, "WBNB: insufficient allowance");
            allowance[from][msg.sender] -= value;
        }

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @notice 便捷函数：为指定地址存入BNB
     */
    function depositTo(address to) public payable {
        balanceOf[to] += msg.value;
        emit Deposit(to, msg.value);
        console.log("WBNB: Deposited", msg.value / 1e18, "BNB for", to);
    }

    /**
     * @notice 便捷函数：提取所有BNB
     */
    function withdrawAll() public {
        uint256 balance = balanceOf[msg.sender];
        if (balance > 0) {
            withdraw(balance);
        }
    }

    /**
     * @notice 获取合约的BNB储备
     */
    function getReserves() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Mint函数（仅用于测试兼容性）
     * @dev 实际上是deposit的别名
     */
    function mint(address to, uint256 amount) external payable {
        require(msg.value == amount, "WBNB: must send exact BNB amount");
        balanceOf[to] += amount;
        emit Deposit(to, amount);
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Burn函数（仅用于测试兼容性）
     * @dev 实际上是withdraw的别名
     */
    function burn(address from, uint256 amount) external {
        require(from == msg.sender || allowance[from][msg.sender] >= amount, "WBNB: unauthorized");
        require(balanceOf[from] >= amount, "WBNB: insufficient balance");
        
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        
        balanceOf[from] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(from, amount);
        emit Transfer(from, address(0), amount);
    }
}