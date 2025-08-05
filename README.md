# 💰 DeFi Salary Escrow Contract

A decentralized salary escrow system built on Stacks blockchain that enables employers to securely manage employee payments through smart contracts.

## 🌟 Features

- 🏢 **Employer Fund Management**: Deposit and manage funds for salary payments
- 📋 **Escrow Agreements**: Create automated salary payment agreements
- ⏰ **Scheduled Payments**: Weekly or monthly automated salary releases
- 💸 **Employee Withdrawals**: Secure salary withdrawals when payments are due
- 🔧 **Agreement Management**: Update salary amounts and payment periods
- 🛡️ **Security Features**: Emergency withdrawal and agreement termination

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Run Clarinet commands to interact with the contract

## 📖 Usage

### For Employers 👔

#### 1. Deposit Funds
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract deposit-funds u1000000)
```

#### 2. Create Escrow Agreement
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract create-escrow-agreement 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u100000 u1008)
```
*Parameters: employee-address, salary-amount, payment-period-in-blocks*

#### 3. Fund the Escrow
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract fund-escrow 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u500000)
```

#### 4. Terminate Agreement
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract terminate-agreement 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### For Employees 👨‍💼

#### Withdraw Salary
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract withdraw-salary 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```
*Parameter: employer-address*

### Read-Only Functions 📊

#### Check Escrow Agreement
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract get-escrow-agreement employer-address employee-address)
```

#### Check Owed Payments
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract calculate-owed-payments employer-address employee-address)
```

#### Check Payment Due Status
```clarity
(contract-call? .DeFi-Salary-Escrow-Contract is-payment-due employer-address employee-address)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `deposit-funds` | Deposit STX into employer balance | `amount` |
| `create-escrow-agreement` | Create new salary agreement | `employee`, `salary-amount`, `payment-period` |
| `fund-escrow` | Add funds to specific escrow | `employee`, `amount` |
| `withdraw-salary` | Employee withdraws due salary | `employer` |
| `terminate-agreement` | End escrow agreement | `employee` |
| `update-salary-amount` | Modify salary amount | `employee`, `new-amount` |
| `update-payment-period` | Change payment frequency | `employee`, `new-period` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-escrow-agreement` | Get agreement details | Agreement data |
| `calculate-owed-payments` | Calculate due payments | Amount owed |
| `is-payment-due` | Check if payment is due | Boolean |
| `get-employer-balance` | Get employer's balance | Balance amount |

## ⚡ Payment Periods

- **Weekly**: ~1008 blocks (1 week ≈ 1008 blocks)
- **Monthly**: ~4320 blocks (1 month ≈ 4320 blocks)
- **Custom**: Any number of blocks

## 🛡️ Security Features

- ✅ Owner-only emergency functions
- ✅ Balance validation before transfers
- ✅ Agreement existence checks
- ✅ Active agreement validation
- ✅ Insufficient funds protection

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only |
| u101 | Not found |
| u102 | Unauthorized |
| u103 | Insufficient funds |
| u104 | Invalid amount |
| u105 | Invalid period |
| u106 | Already exists |
| u107 | Not due |
