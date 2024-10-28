# Starknet Betting Contract

## Deployment
The contract is currently deployed on Starknet Sepolia testnet:

- **Contract Address:** `0x025b695630d364467d529d338551726633c34906192f68f773d2c160e5f6be72`
- **View on Starkscan:** [Contract on Starkscan](https://sepolia.starkscan.co/contract/0x025b695630d364467d529d338551726633c34906192f68f773d2c160e5f6be72#overview)

## Overview
A smart contract built on Starknet that implements a betting system with an ETH prize pool and a points reward mechanism. The contract allows users to place bets using ETH while maintaining an automated prize pool system and rewarding participants with points.

## Features
- **ETH Prize Pool**: Automatically tracks and updates the total prize pool based on the contract's ETH (ERC20) balance
- **User Points System**: Rewards bettors with points for participation
- **Real-time Balance Tracking**: Maintains accurate prize pool records by syncing with actual contract ETH balance
- **Event Emission**: Emits events for bet placement and points earned

## Key Functions

### `get_prize_pool`
- Returns the current prize pool amount
- Automatically syncs the stored prize pool with the contract's actual ETH balance
- Ensures accurate prize pool reporting at all times

### `get_user_points`
- Retrieves the total points accumulated by a specific user
- Takes user's address as input
- Returns the user's current point balance

### `place_bet`
- Allows users to place bets using ETH
- Validates bet amount and user's ETH balance
- Automatically updates the prize pool
- Awards points to the bettor
- Emits a `BetPlaced` event with transaction details

## Technical Implementation
- Built on Starknet using Cairo
- Integrates with OpenZeppelin's ERC20 interface
- Uses efficient storage management through Starknet's storage mapping
- Implements event system for transaction tracking

## Prerequisites
- Requires ETH approval for contract interactions
- Users must have sufficient ETH balance for betting
- Compatible with Starknet-supported wallets

## Security Considerations
- Users should approve the contract for ETH transfers before placing bets
- Minimum bet amount must be greater than 0
- Contract balance is automatically synced to prevent discrepancies

## Events
### BetPlaced
Emitted when a bet is successfully placed, containing:
- User address
- Bet amount
- Points earned

## Usage Example
```rust
// To place a bet
contract.place_bet(user_address, bet_amount);

// To check prize pool
let current_pool = contract.get_prize_pool();

// To check user points
let user_points = contract.get_user_points(user_address);
```
