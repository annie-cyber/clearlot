# ClearLot

A transparent, decentralized marketplace for digital asset auctions built on the Stacks blockchain using Clarity smart contracts.

## Overview

ClearLot provides a trustless environment where asset holders can initiate lot sales for their digital assets while participants compete through transparent bidding mechanisms. The platform ensures fair price discovery and secure asset transfers without intermediaries.

## Key Features

- **Transparent Lot Management**: Asset holders can initiate lots with custom duration and reserve pricing
- **Competitive Bidding**: Open bidding system with real-time leading bid tracking
- **Flexible Lot Control**: Initiators can conclude lots early or withdraw unbid lots
- **Marketplace Commission**: Configurable commission structure for platform sustainability
- **Asset Metadata Support**: Rich asset descriptions and metadata URI support

## Core Concepts

### Lots
Digital asset sales initiated by asset holders with defined parameters:
- Asset title and detailed descriptions
- Metadata URI for additional asset information
- Custom lot duration and reserve pricing
- Real-time bidding status tracking

### Participants
Users who submit competitive bids on active lots, with automatic leading bid updates and transparent bid history.

### Settlement
Automated settlement process ensuring fair asset transfer to winning participants and payment distribution to initiators.

## Smart Contract Functions

### Lot Management
- `initiate-lot`: Create new asset lots with custom parameters
- `conclude-lot-early`: Allow initiators to end lots before scheduled conclusion
- `withdraw-lot`: Enable lot withdrawal when no bids exist

### Bidding System
- `submit-bid`: Place competitive bids on active lots
- `get-participant-bid`: Query individual bid details
- `is-lot-live`: Check lot status and activity

### Administrative
- `update-marketplace-commission`: Adjust platform commission rates (owner only)

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Commission**: 5% default (adjustable up to 10%)
- **Precision**: Basis points (1/100th of 1%)

## Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Access to Stacks blockchain testnet/mainnet
- Clarity CLI for local development

### Deployment
1. Clone the repository
2. Configure your Stacks network settings
3. Deploy the contract using Clarinet or direct deployment
4. Initialize lot operations through the contract interface

### Usage Example
```clarity
;; Initiate a new lot
(contract-call? .clearlot initiate-lot 
  "Digital Artwork #001"
  "Limited edition digital painting with certificate of authenticity"
  "https://metadata.example.com/artwork/001.json"
  u144 ;; 144 blocks duration
  u1000000) ;; 1,000,000 microSTX reserve price

;; Submit a bid
(contract-call? .clearlot submit-bid u1 u1500000) ;; Bid 1,500,000 microSTX on lot #1
```

## Security Considerations

- All lot operations are on-chain and transparent
- Bid validation prevents manipulation and ensures fair competition
- Access controls restrict administrative functions to contract owner
- Asset claims require proper authorization and timing verification

## Contributing

Contributions are welcome through pull requests. Please ensure all code follows Clarity best practices and includes comprehensive testing.