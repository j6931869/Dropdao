# 🚚 DropDAO - Last-Mile Delivery DAO

> 🌟 A community-governed gig delivery network powered by blockchain technology

## 📋 Overview

DropDAO is a decentralized autonomous organization (DAO) that revolutionizes last-mile delivery through community governance. Customers can request deliveries, drivers can accept and complete them, and the entire network is governed by its participants.

## ✨ Features

### 🚗 For Drivers
- **Register as Driver**: Join the network with your name and start earning
- **Accept Deliveries**: Browse and accept available delivery requests
- **Complete Deliveries**: Mark deliveries as completed and receive payment
- **Build Reputation**: Earn ratings from customers to increase trustworthiness

### 📦 For Customers
- **Create Delivery Requests**: Post pickup/delivery locations with payment
- **Track Status**: Monitor delivery progress in real-time
- **Rate Drivers**: Provide feedback to maintain service quality

### 🏛️ DAO Governance
- **Create Proposals**: Submit ideas for network improvements
- **Vote on Changes**: Participate in democratic decision-making
- **Treasury Management**: Platform fees fund community initiatives

## 🚀 Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <repository-url>
cd dropdao
clarinet check
```

### Deployment

```bash
clarinet deploy
```

## 📖 Usage Guide

### 🔧 Driver Registration
```clarity
(contract-call? .dropdao register-driver "John Driver")
```

### 📋 Create Delivery Request
```clarity
(contract-call? .dropdao create-delivery "123 Pickup St" "456 Delivery Ave" u1000000)
```

### ✅ Accept Delivery
```clarity
(contract-call? .dropdao accept-delivery u1)
```

### 🏁 Complete Delivery
```clarity
(contract-call? .dropdao complete-delivery u1)
```

### ⭐ Rate Driver
```clarity
(contract-call? .dropdao rate-driver u1 u5)
```

### 🗳️ Create Proposal
```clarity
(contract-call? .dropdao create-proposal "Reduce Platform Fee" "Lower fee from 5% to 3%")
```

### 🗳️ Vote on Proposal
```clarity
(contract-call? .dropdao vote-on-proposal u1 true)
```

## 📊 Read-Only Functions

### 📈 Get Delivery Info
```clarity
(contract-call? .dropdao get-delivery u1)
```

### 👤 Get Driver Profile
```clarity
(contract-call? .dropdao get-driver 'SP1234...)
```

### 💰 Check DAO Treasury
```clarity
(contract-call? .dropdao get-dao-treasury)
```

## 🔧 Contract Architecture

### 📋 Data Structures
- **Deliveries**: Track all delivery requests and their status
- **Drivers**: Store driver profiles, ratings, and earnings
- **Proposals**: Manage DAO governance proposals
- **Votes**: Record voting participation

### 💰 Economic Model
- Platform fee: 5% (adjustable via governance)
- Driver payments: 95% of delivery fee
- DAO treasury: Accumulated platform fees

### 🛡️ Security Features
- Authorization checks for all critical functions
- Payment escrow during delivery process
- Rating system for quality assurance
- Democratic governance for platform changes

## 🎯 Delivery Status Flow

1. **Pending** → Customer creates delivery request
2. **Assigned** → Driver accepts the delivery
3. **Completed** → Driver completes delivery and receives payment

## 🏛️ Governance Process

1. **Proposal Creation** → Any registered driver can create proposals
2. **Voting Period** → 144 blocks (~24 hours) for voting
3. **Execution** → Successful proposals can be implemented

## 🔮 Future Enhancements

- 🌍 Multi-city expansion
- 📱 Mobile app integration  
- 🤖 AI-powered route optimization
- 💎 Token rewards for active participants
- 🔒 Dispute resolution system

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request
4. Participate in DAO governance

## 📄 License

MIT License - Build the future of delivery together! 🚀


