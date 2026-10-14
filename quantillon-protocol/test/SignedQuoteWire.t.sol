// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SignedExecutionPricing} from "../src/oracle/SignedExecutionPricing.sol";
import {SignedReferenceSource} from "../src/oracle/SignedReferenceSource.sol";
import {SignedQuoteTypes as T} from "../src/libraries/SignedQuoteTypes.sol";

/// @dev Fixed viem-produced fixture is mirrored in the dapp's shared wire package.
contract SignedQuoteWireTest is Test {
    function test_BackendAuthorizationAndSignaturesMatchSolidity() public {
        string memory fixture = vm.readFile("test/fixtures/signed-quote-wire-v1.json");
        vm.chainId(vm.parseJsonUint(fixture, ".chainId"));
        address referenceAddress = vm.parseJsonAddress(fixture, ".referenceSource");
        address executionAddress = vm.parseJsonAddress(fixture, ".module");
        address signer = vm.parseJsonAddress(fixture, ".signer");
        SignedReferenceSource template = new SignedReferenceSource(address(this), address(this), 60, 8100, 200, 300);
        vm.etch(referenceAddress, address(template).code);
        SignedExecutionPricing pricingTemplate = new SignedExecutionPricing(address(this), address(this), referenceAddress, address(this), 25, 1000e18, 60, 25);
        vm.etch(executionAddress, address(pricingTemplate).code);
        SignedReferenceSource source = SignedReferenceSource(referenceAddress);
        SignedExecutionPricing pricing = SignedExecutionPricing(executionAddress);
        bytes memory wire = vm.parseJsonBytes(fixture, ".authorization");
        T.Authorization memory a = abi.decode(wire, (T.Authorization));
        assertEq(keccak256(abi.encode(a)), keccak256(wire));
        assertEq(a.quote.amountIn, 100_000e6);
        assertEq(a.quote.amountOut, 85382513661202185792349);
        bytes32 quoteHash = pricing.quoteDigest(a.quote);
        bytes32 referenceHash = source.digest(a.referenceReport);
        bytes32 capacityHash = pricing.capacityDigest(a.capacityReport);
        assertEq(quoteHash, vm.parseJsonBytes32(fixture, ".quoteDigest"));
        assertEq(referenceHash, vm.parseJsonBytes32(fixture, ".referenceDigest"));
        assertEq(capacityHash, vm.parseJsonBytes32(fixture, ".capacityDigest"));
        assertEq(a.quote.referenceHash, referenceHash);
        assertEq(ECDSA.recover(quoteHash, a.signature), signer);
        assertEq(ECDSA.recover(referenceHash, a.referenceSignature), signer);
        assertEq(ECDSA.recover(capacityHash, a.capacitySignature), signer);
        vm.chainId(31337);
        assertNotEq(pricing.quoteDigest(a.quote), quoteHash);
        assertNotEq(source.digest(a.referenceReport), referenceHash);
        assertNotEq(pricing.capacityDigest(a.capacityReport), capacityHash);
    }
}
