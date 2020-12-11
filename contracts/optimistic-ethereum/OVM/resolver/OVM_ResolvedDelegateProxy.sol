// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

/* Library Imports */
import { OVM_AddressManager } from "./OVM_AddressManager.sol";

/**
 * @title OVM_ResolvedDelegateProxy
 */
contract OVM_ResolvedDelegateProxy {

    /*************
     * Variables *
     *************/

    // Using mappings to store fields to avoid overwriting storage slots in the
    // implementation contract. For example, instead of storing these fields at
    // storage slot `0` & `1`, they are stored at `hash(${FIELD_NAME} + address(this))`
    // See: https://solidity.readthedocs.io/en/v0.7.0/internals/layout_in_storage.html
    mapping(address=>string) private implementationName;
    mapping(address=>OVM_AddressManager) private addressManager;


    /***************
     * Constructor *
     ***************/

    /**
     * @param _ovmAddressManager Address of the OVM_AddressManager.
     * @param _implementationName implementationName of the contract to proxy to.
     */
    constructor(
        address _ovmAddressManager,
        string memory _implementationName
    )
    {
        addressManager[address(this)] = OVM_AddressManager(_ovmAddressManager);
        implementationName[address(this)] = _implementationName;
    }


    /*********************
     * Fallback Function *
     *********************/

    fallback()
        external
    {
        address target = addressManager[address(this)].getAddress((implementationName[address(this)]));
        require(
            target != address(0),
            "Target address must be initialized."
        );

        (bool success, bytes memory returndata) = target.delegatecall(msg.data);

        if (success == true) {
            assembly {
                return(add(returndata, 0x20), mload(returndata))
            }
        } else {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }
}