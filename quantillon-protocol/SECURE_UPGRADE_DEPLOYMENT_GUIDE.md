# 🔐 Secure Upgrade Migration - Deployment Guide

## **Overview**

This guide provides step-by-step instructions for deploying the secure upgrade mechanism that replaces the unrestricted upgrade capability with a timelock and multi-sig system.

## **🔴 CRITICAL: Pre-Migration Checklist**

### **Before Starting Migration**
- [ ] **Backup all current contracts and configurations**
- [ ] **Verify all existing contracts are working correctly**
- [ ] **Ensure all team members are available for deployment**
- [ ] **Have emergency contacts ready**
- [ ] **Test the migration on testnet first**

## **📋 Migration Steps**

### **Step 1: Deploy TimelockUpgradeable Contract**

```bash
# Deploy the timelock contract
forge create TimelockUpgradeable \
  --rpc-url <RPC_URL> \
  --private-key <DEPLOYER_PRIVATE_KEY>
```

**Configuration Parameters:**
- `UPGRADE_DELAY`: 48 hours (recommended)
- `MULTI_SIG_THRESHOLD`: 3 out of 5 (recommended)
- `MULTI_SIG_MEMBERS`: Array of trusted addresses

### **Step 2: Configure Multi-Sig Members**

```solidity
// Add multi-sig members to timelock
timelock.addMultiSigMember(address1);
timelock.addMultiSigMember(address2);
timelock.addMultiSigMember(address3);
timelock.addMultiSigMember(address4);
timelock.addMultiSigMember(address5);

// Set threshold (3 out of 5)
timelock.setMultiSigThreshold(3);
```

### **Step 3: Deploy Updated Contracts**

Deploy each contract with the new timelock parameter:

#### **QEUROToken**
```bash
forge create QEUROToken \
  --rpc-url <RPC_URL> \
  --private-key <DEPLOYER_PRIVATE_KEY>
```

#### **QTIToken**
```bash
forge create QTIToken \
  --rpc-url <RPC_URL> \
  --private-key <DEPLOYER_PRIVATE_KEY>
```

#### **QuantillonVault**
```bash
forge create QuantillonVault \
  --rpc-url <RPC_URL> \
  --private-key <DEPLOYER_PRIVATE_KEY>
```

### **Step 4: Initialize Contracts with Timelock**

```solidity
// Initialize QEUROToken
qeuroToken.initialize(
    admin,
    vault,
    timelockAddress
);

// Initialize QTIToken
qtiToken.initialize(
    admin,
    treasury,
    timelockAddress
);

// Initialize QuantillonVault
quantillonVault.initialize(
    admin,
    qeuroTokenAddress,
    usdcAddress,
    oracleAddress,
    timelockAddress
);
```

### **Step 5: Verify Contract Configurations**

```solidity
// Verify timelock is set correctly
assert(qeuroToken.timelock() == timelockAddress);
assert(qtiToken.timelock() == timelockAddress);
assert(quantillonVault.timelock() == timelockAddress);

// Verify secure upgrades are enabled
assert(qeuroToken.secureUpgradesEnabled() == true);
assert(qtiToken.secureUpgradesEnabled() == true);
assert(quantillonVault.secureUpgradesEnabled() == true);
```

## **🔧 Testing the Upgrade Process**

### **Test Upgrade Proposal**

```solidity
// 1. Propose upgrade
timelock.proposeUpgrade(
    newImplementationAddress,
    "Security patch for QEUROToken"
);

// 2. Wait for timelock period (48 hours)
// 3. Get multi-sig approvals
timelock.approveUpgrade(newImplementationAddress);

// 4. Execute upgrade
timelock.executeUpgrade(newImplementationAddress);
```

### **Test Emergency Upgrade**

```solidity
// Emergency upgrade (bypasses timelock)
// Only available if timelock is not set
qeuroToken.emergencyUpgrade(
    newImplementationAddress,
    "Emergency security fix"
);
```

## **⚠️ Security Considerations**

### **Multi-Sig Requirements**
- **Minimum 3 signers** for any upgrade
- **Geographically distributed** signers
- **Hardware wallets** for all signers
- **Regular key rotation** (every 6 months)

### **Timelock Settings**
- **48-hour minimum delay** for all upgrades
- **Community notification** during delay period
- **Emergency bypass** only for critical issues

### **Access Control**
- **Revoke old UPGRADER_ROLE** from all addresses
- **Grant new roles** only to timelock contract
- **Monitor all upgrade attempts**

## **🚨 Emergency Procedures**

### **If Timelock is Compromised**
1. **Immediate pause** of all contracts
2. **Emergency upgrade** to remove timelock
3. **Deploy new timelock** with new keys
4. **Re-enable secure upgrades**

### **If Multi-Sig is Compromised**
1. **Freeze multi-sig operations**
2. **Deploy new multi-sig** with new members
3. **Update timelock configuration**
4. **Verify all changes**

## **📊 Post-Migration Verification**

### **Contract Verification**
```bash
# Verify all contracts on Etherscan
forge verify-contract <CONTRACT_ADDRESS> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key <API_KEY>
```

### **Functionality Tests**
- [ ] **Minting QEURO** works correctly
- [ ] **Burning QEURO** works correctly
- [ ] **Governance voting** works correctly
- [ ] **Emergency pause** works correctly
- [ ] **Recovery functions** work correctly

### **Security Tests**
- [ ] **Upgrade proposal** requires timelock
- [ ] **Multi-sig approval** required for execution
- [ ] **Emergency upgrade** bypasses timelock
- [ ] **Old upgrade functions** are disabled

## **📈 Monitoring and Maintenance**

### **Regular Checks**
- **Weekly**: Review upgrade proposals
- **Monthly**: Verify multi-sig member status
- **Quarterly**: Test emergency procedures
- **Annually**: Rotate multi-sig keys

### **Alert System**
- **Upgrade proposals** → Immediate notification
- **Multi-sig changes** → Immediate notification
- **Emergency upgrades** → Immediate notification
- **Timelock bypasses** → Immediate notification

## **🔗 Useful Commands**

### **Check Contract Status**
```solidity
// Check if secure upgrades are enabled
qeuroToken.secureUpgradesEnabled()
qtiToken.secureUpgradesEnabled()
quantillonVault.secureUpgradesEnabled()

// Check timelock address
qeuroToken.timelock()
qtiToken.timelock()
quantillonVault.timelock()
```

### **Check Upgrade Status**
```solidity
// Check pending upgrades
timelock.getPendingUpgrade(newImplementationAddress)

// Check multi-sig status
timelock.getMultiSigMembers()
timelock.getMultiSigThreshold()
```

## **📞 Support and Contacts**

### **Emergency Contacts**
- **Technical Lead**: [Contact Info]
- **Security Team**: [Contact Info]
- **Legal Team**: [Contact Info]

### **Documentation**
- **Technical Docs**: [Link]
- **Security Audit**: [Link]
- **Governance Docs**: [Link]

---

**⚠️ IMPORTANT**: This migration significantly improves security but requires careful coordination. Always test on testnet first and have rollback procedures ready.
