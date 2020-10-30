pragma solidity ^0.7.0;

/* Library Imports */
import { Lib_BytesUtils } from "../../libraries/utils/Lib_BytesUtils.sol";
import { Lib_OVMCodec } from "../../libraries/codec/Lib_OVMCodec.sol";
import { Lib_ECDSAUtils } from "../../libraries/utils/Lib_ECDSAUtils.sol";
import { Lib_SafeExecutionManagerWrapper } from "../../libraries/wrappers/Lib_SafeExecutionManagerWrapper.sol";

/**
 * @title OVM_SequencerEntrypoint
 */
contract OVM_SequencerEntrypoint {
    /*
     * Data Structures
     */
    
    enum TransactionType {
        NATIVE_ETH_TRANSACTION,
        ETH_SIGNED_MESSAGE
    }


    /*
     * Fallback Function
     */

    /**
     * We use the fallback here to parse the compressed encoding used by the
     * Sequencer.
     *
     * Calldata format:
     * - [ 1 byte   ] Transaction type (00 for EOA create, 01 for native tx, 02 for eth signed tx)
     * - [ 32 bytes ] Signature `r` parameter
     * - [ 32 bytes ] Signature `s` parameter
     * - [ 1 byte   ] Signature `v` parameter
     * - [ ?? bytes ] :
     *      IF transaction type == 01
     *      - [ 32 bytes ] Hash of the signed message
     *      ELSE
     *      - [ 3 bytes  ] Gas Limit
     *      - [ 3 bytes  ] Gas Price
     *      - [ 3 byte   ] Transaction Nonce
     *      - [ 20 bytes  ] Transaction target address
     *      - [ ?? bytes ] Transaction data
     */
    fallback()
        external
    {
        TransactionType transactionType = _getTransactionType(Lib_BytesUtils.toUint8(msg.data, 0));
        bytes32 r = Lib_BytesUtils.toBytes32(Lib_BytesUtils.slice(msg.data, 1, 32));
        bytes32 s = Lib_BytesUtils.toBytes32(Lib_BytesUtils.slice(msg.data, 33, 32));
        uint8 v = Lib_BytesUtils.toUint8(msg.data, 65);
        
        // Remainder is the transaction to execute.
        bytes memory compressedTx = Lib_BytesUtils.slice(msg.data, 66);
        bool isEthSignedMessage = transactionType == TransactionType.ETH_SIGNED_MESSAGE;
        // Need to decompress and then re-encode the transaction based on the original encoding.
        bytes memory encodedTx = Lib_OVMCodec.encodeEIP155Transaction(
            Lib_OVMCodec.decompressEIP155Transaction(compressedTx),
            isEthSignedMessage
        );

        address target = Lib_ECDSAUtils.recover(
            encodedTx,
            isEthSignedMessage,
            uint8(v),
            r,
            s,
            Lib_SafeExecutionManagerWrapper.safeCHAINID(msg.sender)
        );
        if (Lib_SafeExecutionManagerWrapper.safeEXTCODESIZE(msg.sender, target) == 0) {
            //ProxyEOA has not yet been deployed for this EOA
            bytes32 messageHash = Lib_ECDSAUtils.getMessageHash(encodedTx, isEthSignedMessage);
            Lib_SafeExecutionManagerWrapper.safeCREATEEOA(msg.sender, messageHash, uint8(v), r, s);
        } else {
            //ProxyEOA has already been deployed for this EOA, continue to CALL
            bytes memory callbytes = abi.encodeWithSignature(
                "execute(bytes,uint8,uint8,bytes32,bytes32)",
                encodedTx,
                isEthSignedMessage,
                uint8(v),
                r,
                s
            );

            Lib_SafeExecutionManagerWrapper.safeCALL(
                msg.sender,
                gasleft(),
                target,
                callbytes
            );
        }
    }
    
    /*
     * Internal Functions
     */
    
    /**
     * Converts a uint256 into a TransactionType enum.
     * @param _transactionType Transaction type index.
     * @return Transaction type enum value.
     */
    function _getTransactionType(
        uint8 _transactionType
    )
        internal
        returns (
            TransactionType
        )
    {
        if (
            _transactionType != 2 && _transactionType != 0
        ) {
            Lib_SafeExecutionManagerWrapper.safeREVERT(
                msg.sender,
                bytes("Transaction type must be 0 or 2")
            );
        }

        if (_transactionType == 0) {
            return TransactionType.NATIVE_ETH_TRANSACTION;
        }
        return TransactionType.ETH_SIGNED_MESSAGE;
    }
}