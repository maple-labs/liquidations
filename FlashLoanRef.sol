pragma solidity ^0.8.0;

//interfaces discussed above
import "./IERC3156FlashBorrower.sol";
import "./IERC3156FlashLender.sol";

//interface for our contract to know how does an ERC20 looks like
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//The borrower implementation
contract FlashBorrower is IERC3156FlashBorrower {
    enum Action {NORMAL, OTHER}
    IERC3156FlashLender lender;
    constructor (IERC3156FlashLender lender_) {
        lender = lender_;
    }

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external override returns(bool) {
        require(msg.sender == address(lender), "FlashBorrower: Untrusted lender");
        require(initiator == address(this), "FlashBorrower: Untrusted loan initiator");
        (Action action) = abi.decode(data, (Action));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(address token, uint256 amount) public {
        bytes memory data = abi.encode(Action.NORMAL);
        uint256 _allowance = IERC20(token).allowance(address(this), address(lender));
        uint256 _fee = lender.flashFee(token, amount);
        uint256 _repayment = amount + _fee;
        IERC20(token).approve(address(lender), _allowance + _repayment);
        lender.flashLoan(this, token, amount, data);
    }
}

//The Lender implementation
contract FlashLender is IERC3156FlashLender {
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    mapping(address => bool) public supportedTokens;
    uint256 public fee; //  1 == 0.0001 %.

    constructor(address[] memory supportedTokens_, uint256 fee_) {
        for (uint256 i = 0; i < supportedTokens_.length; i++) {
            supportedTokens[supportedTokens_[i]] = true;
        }
        fee = fee_;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external override returns(bool) {
        require(supportedTokens[token], "FlashLender: Unsupported currency");
        uint256 fee = _flashFee(token, amount);
        require(IERC20(token).transfer(address(receiver), amount),"FlashLender: Transfer failed");
        require(receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,"FlashLender: Callback failed");
        require(IERC20(token).transferFrom(address(receiver), address(this), amount + fee),"FlashLender: Repay failed");
        return true;
    }

    function flashFee(address token, uint256 amount) external view override returns (uint256) {
        require(supportedTokens[token],"FlashLender: Unsupported currency");
        return _flashFee(token, amount);
    }

    function _flashFee(address token,uint256 amount) internal view returns (uint256) {
        return amount * fee / 10000;
    }

    function maxFlashLoan(address token) external view override returns (uint256) {
        return supportedTokens[token] ? IERC20(token).balanceOf(address(this)) : 0;
    }
}
