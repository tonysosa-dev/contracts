// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.8.0;
pragma experimental ABIEncoderV2;

/* Interface Imports */
import { iOVM_L1TokenGateway } from "../../../iOVM/bridge/tokens/iOVM_L1TokenGateway.sol";

/* Contract Imports */
import { UniswapV2ERC20 } from "../../../libraries/standards/UniswapV2ERC20.sol";

/* Library Imports */
import { Abs_L2DepositedToken } from "./Abs_L2DepositedToken.sol";

/**
 * @title OVM_L2DepositedERC20
 * @dev The L2 Deposited ERC20 is an ERC20 implementation which represents L1 assets deposited into L2.
 * This contract mints new tokens when it hears about deposits into the L1 ERC20 gateway.
 * This contract also burns the tokens intended for withdrawal, informing the L1 gateway to release L1 funds.
 *
 * Compiler used: optimistic-solc
 * Runtime target: OVM
 */
contract OVM_L2DepositedERC20 is Abs_L2DepositedToken, UniswapV2ERC20 {

    /***************
     * Constructor *
     ***************/

    /**
     * @param _l2CrossDomainMessenger Cross-domain messenger used by this contract.
     * @param _decimals ERC20 decimals
     * @param _name ERC20 name
     * @param _symbol ERC20 symbol
     */
    constructor(
        address _l2CrossDomainMessenger,
        uint8 _decimals,
        string memory _name,
        string memory _symbol
    )
        public
        Abs_L2DepositedToken(_l2CrossDomainMessenger)
        UniswapV2ERC20(_decimals, _name, _symbol)
    {}

    function _handleInitiateWithdrawal(
        address _to,
        uint _amount
    )
        internal
        override
    {
        _burn(msg.sender, _amount);
    }

    function _handleFinalizeDeposit(
        address _to,
        uint _amount
    )
        internal
        override
    {
        _mint(_to, _amount);
    }
}