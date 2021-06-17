pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
// SPDX-License-Identifier: Unlicensed
import './Ownable.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Pair.sol';
import './lib/Address.sol';
import "./lib/SafeMath.sol";
import './lib/FixedPoint.sol';


contract WhaleFall is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using FixedPoint for FixedPoint.uq144x112;
    using FixedPoint for FixedPoint.uq112x112;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 1000000000 * 10**6 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    string private constant _name = "WhaleFall";
    string private constant _symbol = "WHALE";
    uint8 private constant _decimals = 9;


    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    mapping (address => uint) private _lastReceiveTime;
    address[] private _excluded;

    mapping (address => bool) private _isWhale;
    mapping (address => bool) private _isExcludedFromWhale;
    address[] private _whale;
    uint256 public whaleLine = 2500000 * 10**6 * 10**9;
    uint256 public constant whalePriceBase = 5714285714;
    uint256 public priceDeductCount;
    uint256 public _whaleDeductRate = 1;

    mapping (address => bool) private _isHodl;
    uint256 public hodlCount;
    uint256 public constant hodlLine = 100 * 10**6 * 10**9;
    uint256 public constant hodlNumBase = 10000;
    uint256 public hodlDeductCount;

    uint256 public constant transferUSDTLimit = 300 * 10**18;
    uint256 public constant TRADE_LIMIT_PEROID = 15 days;
    uint private _minReceiveTime = 2;
    uint256 public _tradeLimitDate;
    uint256 public _maxTxAmount = 1000000000 * 10**6 * 10**9;

    uint256 public _taxFee = 5;
    uint256 private _previousTaxFee = _taxFee;
    uint256 public _liquidityFee = 5;
    uint256 private _previousLiquidityFee = _liquidityFee;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public immutable usdt;
    address public immutable bnb;
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    uint256 public numTokensSellToAddToLiquidity = 100000 * 10**6 * 10**9;
    uint256 private _tFeeTotal;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event AddWhale(address whale);
    event BurnWhale(address whale, uint256 amount);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor (address _uniswapRouter, address _usdtAddress, address _bnbAddress) public {
        _rOwned[_msgSender()] = _rTotal/2;
        _rOwned[address(0)] = _rTotal/2;

        _tradeLimitDate = block.timestamp + TRADE_LIMIT_PEROID;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_uniswapRouter);
        // Create a uniswap pair for usdt token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _usdtAddress);
        usdt = _usdtAddress;
        bnb = _bnbAddress;
        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        _isExcludedFromWhale[owner()] = true;
        _isExcludedFromWhale[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
        emit Transfer(_msgSender(), address(0), _tTotal/2);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function getWhalePerUSDTPrice(uint amountIn) public view returns (uint amountOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapV2Pair);
        address token0 = pair.token0();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();

        if(token0 == address(this)){
            amountOut = (FixedPoint.fraction(reserve0, reserve1).mul(amountIn)).decode144();
        }
        else{
            amountOut = (FixedPoint.fraction(reserve1, reserve0).mul(amountIn)).decode144();
        }
    }

    function getUSDTPerWhalePrice(uint amountIn) public view returns (uint amountOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapV2Pair);
        address token0 = pair.token0();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();

        if(token0 == address(this)){
            amountOut = (FixedPoint.fraction(reserve1, reserve0).mul(amountIn)).decode144();
        }
        else{
            amountOut = (FixedPoint.fraction(reserve0, reserve1).mul(amountIn)).decode144();
        }
    }

    function isWhale(address account) public view returns (bool) {
        return _isWhale[account];
    }

    function isHodl(address account) public view returns (bool) {
        return _isHodl[account];
    }

    function dividendOf(address account) public view  returns (uint256) {
        return balanceOf(account)-_tOwned[account];
    }

    function tOwnedOf(address account) public view  returns (uint256) {
        return _tOwned[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public onlyOwner{
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function _burnWhale(address whaleAddress, uint256 tAmount) private {
        require(_isWhale[whaleAddress], "address is not whale");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[whaleAddress] = _rOwned[whaleAddress].sub(rAmount);
        _tOwned[whaleAddress] = _tOwned[whaleAddress].sub(tAmount);
        _rOwned[address(0)] = _rOwned[address(0)].add(rAmount);
        emit BurnWhale(whaleAddress, tAmount);
    }

    function _burnAllWhale() private {
        for (uint256 i = 0; i < _whale.length; i++) {
            _burnWhale(_whale[i], calculateWhaleDeductFee(_tOwned[_whale[i]]));
        }
    }

    function triggerBurnWhale() public onlyOwner{
        uint d = hodlCount.div(hodlNumBase);
        if (d >= hodlDeductCount.add(1)){
            _burnAllWhale();
            hodlDeductCount = hodlDeductCount.add(1);
        }

        uint p = getUSDTPerWhalePrice(1*10**9).div(whalePriceBase);
        if (p >= priceDeductCount.add(1).mul(10)){
            _burnAllWhale();
            priceDeductCount = priceDeductCount.add(1);
        }
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        require(!_isWhale[account], "Whale Account can't excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function addWhale(address account) public onlyOwner {
        require(!_isWhale[account], "Account is whale");
        require(!_isExcluded[account], "Excluded account can't be whale");
        require(!_isExcludedFromWhale[account], "Account is excluded from whale");
        require(!isExchangeAddr(account), "ExchangeAddr can not be whale");
        _addWhale(account);
    }

    function _addWhale(address account) private {
        _isWhale[account] = true;
        _whale.push(account);
        _tOwned[account] = tokenFromReflection(_rOwned[account]);
        emit AddWhale(account);
    }

    function removeWhale(address account) external onlyOwner {
        require(_isWhale[account], "Account is not whale");
        for (uint256 i = 0; i < _whale.length; i++) {
            if (_whale[i] == account) {
                _whale[i] = _whale[_whale.length - 1];
                _isWhale[account] = false;
                _whale.pop();
                _tOwned[account] = 0;
                break;
            }
        }
    }

    function excludeFromWhale(address account) public onlyOwner {
        _isExcludedFromWhale[account] = true;
    }

    function includeInWhale(address account) public onlyOwner {
        _isExcludedFromWhale[account] = false;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }

    function setWhaleDeductRate(uint256 whaleDeductRate) external onlyOwner() {
        _whaleDeductRate = whaleDeductRate;
    }

    function setMinReceiveTime(uint256 minReceiveTime) external onlyOwner() {
        _minReceiveTime = minReceiveTime;
    }

    function setNumTokensSellToAddToLiquidity(uint256 _numTokensSellToAddToLiquidity) external onlyOwner() {
        numTokensSellToAddToLiquidity = _numTokensSellToAddToLiquidity;
    }

    function setWhaleLine(uint256 _whaleline) external onlyOwner() {
        whaleLine = _whaleline;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10**2
        );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }

    function calculateWhaleDeductFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_whaleDeductRate).div(
            10**2
        );
    }

    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;

        _taxFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromWhale(address account) public view returns(bool) {
        return _isExcludedFromWhale[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        //        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if(from != owner() && to != owner()){
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            if (block.timestamp<=_tradeLimitDate)
            {
                require(amount <= getWhalePerUSDTPrice(transferUSDTLimit), "Transfer amount exceeds the initMaxTxAmount.");
            }
            if(!isExchangeAddr(to))
            {
                require(now.sub(_lastReceiveTime[to]) >= _minReceiveTime,"can not receive in 2s");
            }
        }
        _lastReceiveTime[to]  = now;

        if(isWhale(from)){
            require(amount <= dividendOf(from), "Transfer amount exceeds the dividendAmount.");
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);

        if(
            !isExchangeAddr(to) &&
        balanceOf(to)>=whaleLine &&
        !isWhale(to) &&
        !_isExcludedFromWhale[to]
        )
        {
            revert('Can not hold more than whaleLine');
        }
    }

    function isExchangeAddr(address account) private returns (bool){
        if(account == uniswapV2Pair || account == address(uniswapV2Router)){
            return true;
        }
        return false;
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = IERC20(usdt).balanceOf(address(this));

        // swap tokens for USDT
        swapTokensForUSDT(half); // <- this breaks the USDT -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = IERC20(usdt).balanceOf(address(this)).sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForUSDT(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> usdt -> bnb
        address[] memory path1 = new address[](3);
        path1[0] = address(this);
        path1[1] = usdt;
        path1[2] = bnb;
        // generate the uniswap pair path of bnb -> usdt
        address[] memory path2 = new address[](2);
        path2[0] = bnb;
        path2[1] = usdt;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uint256 bnbAmountBefore = IERC20(bnb).balanceOf(address(this));

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path1,
            address(this),
            block.timestamp
        );

        uint256 bnbAmountAfter = IERC20(bnb).balanceOf(address(this));

        IERC20(bnb).approve(address(uniswapV2Router), bnbAmountAfter - bnbAmountBefore);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bnbAmountAfter - bnbAmountBefore,
            0,
            path2,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 usdtAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        IERC20(usdt).approve(address(uniswapV2Router), usdtAmount);

        // add the liquidity
        uniswapV2Router.addLiquidity(
            address(this),
            usdt,
            tokenAmount,
            usdtAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();

        if(isHodl(sender) && (balanceOf(sender) < hodlLine) && !isExchangeAddr(sender)){
            _isHodl[sender] = false;
            hodlCount = hodlCount.sub(1);
        }

        if(!isHodl(recipient) && (balanceOf(recipient) >= hodlLine) && !isExchangeAddr(recipient)){
            _isHodl[recipient] = true;
            hodlCount = hodlCount.add(1);
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        if(isWhale(recipient)){
            _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        }
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        if(isWhale(recipient)){
            _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        }
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}