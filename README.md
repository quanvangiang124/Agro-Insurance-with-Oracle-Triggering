# 🌾 Agro Insurance with Oracle Triggering

A decentralized crop insurance platform built on Stacks blockchain that automatically triggers payouts based on weather data from authorized oracles.

## 🚀 Features

- **🏛️ Decentralized Insurance**: Create and manage crop insurance policies on-chain
- **🌤️ Oracle Integration**: Weather data submission from authorized oracles
- **⚡ Automatic Payouts**: Smart contract automatically processes claims based on weather conditions
- **💰 Insurance Pool**: Community-funded insurance pool for payouts
- **📊 Real-time Monitoring**: Track policy status and weather data

## 📋 Contract Functions

### 🔧 Admin Functions
- `set-oracle` - Set the main oracle address
- `authorize-oracle` - Authorize new weather data oracles
- `revoke-oracle` - Revoke oracle authorization

### 💼 Insurance Functions
- `create-policy` - Create a new crop insurance policy
- `claim-insurance` - Claim insurance payout when conditions are met
- `cancel-policy` - Cancel policy within grace period
- `fund-insurance-pool` - Add funds to the insurance pool

### 🌡️ Oracle Functions
- `submit-weather-data` - Submit weather data (authorized oracles only)

### 📖 Read-Only Functions
- `get-policy` - Get policy details
- `get-weather-data` - Get weather data for location and block
- `get-insurance-pool` - Get current pool balance
- `is-oracle-authorized` - Check if oracle is authorized
- `calculate-premium` - Calculate premium for coverage amount
- `get-policy-status` - Get current policy status

## 🛠️ Usage

### Creating a Policy
```clarity
(contract-call? .agro-insurance create-policy 
  "corn" 
  u1000000 
  u1000 
  "Iowa-Farm-001" 
  u500 
  u350)
```

### Submitting Weather Data (Oracle)
```clarity
(contract-call? .agro-insurance submit-weather-data 
  "Iowa-Farm-001" 
  u300 
  u380)
```

### Claiming Insurance
```clarity
(contract-call? .agro-insurance claim-insurance u1)
```

## 📊 Policy Parameters

- **Crop Type**: Type of crop being insured
- **Coverage Amount**: Maximum payout in microSTX
- **Duration**: Policy duration in blocks
- **Location**: Farm/field identifier
- **Min Rainfall**: Minimum rainfall threshold (mm)
- **Max Temperature**: Maximum temperature threshold (°C × 10)

## 💡 How It Works

1. **🌱 Policy Creation**: Farmers create policies by paying premiums (10% of coverage)
2. **🌦️ Weather Monitoring**: Authorized oracles submit weather data regularly
3. **⚖️ Claim Evaluation**: Smart contract checks if weather conditions trigger payouts
4. **💸 Automatic Payout**: Qualifying claims are automatically processed

## 🔒 Security Features

- Oracle authorization system
- Policy ownership verification
- Claim condition validation
- Insurance pool balance checks
- Time-based policy expiration

## 🚀 Getting Started

1. Deploy the contract to Stacks blockchain
2. Fund the insurance pool
3. Authorize weather data oracles
4. Farmers can start creating policies
5. Oracles submit weather data
6. Claims are processed automatically

## 📈 Premium Calculation

Premium = Coverage Amount × 10%

Example: $10,000 coverage = $1,000 premium

## ⚠️ Error Codes

- `u100` - Unauthorized access
- `u101` - Policy not found
- `u102` - Insufficient premium
- `u103` - Policy expired
- `u104` - Policy already claimed
- `u105` - Invalid oracle data
- `u106` - Claim conditions not met
- `u107` - Insufficient pool funds
- `u108` - Oracle not authorized

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

MIT License - see LICENSE file for details
```

**Git Commit Message:**
```
feat: implement agro insurance smart contract with oracle triggering system
```

**GitHub Pull Request Title:**
```
🌾 Add Agro Insurance Smart Contract with Oracle Integration
```

**GitHub Pull Request Description:**
```
## 🌾 Agro Insurance with Oracle Triggering

This PR adds a comprehensive crop insurance smart contract that automatically triggers payouts based on weather data from authorized oracles.

### ✨ Features Added:
- **Decentralized Insurance Policies**: Farmers can create crop insurance policies with customizable parameters
- **Oracle Integration**: Authorized oracles can submit weather data to trigger automatic payouts  
- **Automatic Claim Processing**: Smart contract evaluates weather conditions and processes valid claims
- **Insurance Pool Management**: Community-funded pool system for payouts
- **Admin Controls**: Oracle authorization and contract management functions

### 🔧 Technical Implementation:
- 150+ lines of Clarity smart contract code
- Comprehensive error handling
