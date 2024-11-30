# Starknet Betting Contract

## Deployment
The contract is currently deployed on Starknet Sepolia testnet:
- **Contract Address:** `0x02c27b6caba176944a66319d051535b42e75df95179b3a6c9347533d04370088`
- **View on Starkscan:** [Contract on Starkscan](https://sepolia.starkscan.co/contract/0x2c27b6caba176944a66319d051535b42e75df95179b3a6c9347533d04370088)

## Overview
A smart contract built on Starknet using Cairo language that implements a betting system with an ETH prize pool and a points reward mechanism. The contract allows users to place bets using ETH while maintaining an automated prize pool system and rewarding participants with points. It includes a backend authorization system for secure prize distribution.

## Features
- **Prize Pool**: Automatically tracks and updates the total prize pool based on the contract's ETH (ERC20) balance
- **User Points System**: Rewards bettors with points for participation
- **Real-time Balance Tracking**: Maintains accurate prize pool records by syncing with actual contract ETH balance
- **Backend Authorization**: Secure system for prize distribution controlled by authorized backend
- **Event Emission**: Emits events for bet placement, prize transfers, and betting approvals

## Key Functions

### `approve_betting_amount`
- Allows users to approve the contract to spend their ETH
- Takes approval amount as input
- Returns boolean indicating approval success
- Emits a `BettingApproved` event

### `get_prize_pool`
- Returns the current prize pool amount
- Automatically syncs the stored prize pool with the contract's actual ETH balance
- Ensures accurate prize pool reporting at all times

### `get_user_points`
- Retrieves the total points accumulated by a specific user
- Takes user's address as input
- Returns the user's current point balance

### `transfer_prize`
- Backend-only function for distributing prizes
- Transfers the entire prize pool to the specified user
- Requires backend authorization
- Emits a `PrizeTransferred` event

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
- Implements backend authorization system
- Implements event system for transaction tracking

## Prerequisites
- Requires ETH approval for contract interactions
- Users must have sufficient ETH balance for betting
- Compatible with Starknet-supported wallets
- Backend address must be set during contract deployment

## Security Considerations
- Only authorized backend can transfer prizes
- Users should approve the contract for ETH transfers before placing bets
- Minimum bet amount must be greater than 0
- Contract balance is automatically synced to prevent discrepancies
Allowance checking prevents unauthorized transfers

## Events
### BetPlaced
Emitted when a bet is successfully placed, containing:
- User address
- Bet amount
- Points earned
- Remaining allowance

### BettingApproved
Emitted when a user approves betting amount:
- User address
- Approved amount

### PrizeTransferred
Emitted when a prize is transferred:
- User address (recipient)
- Amount transferred
- Timestamp

## Usage Example
```rust
// To approve betting amount
contract.approve_betting_amount(amount);

// To place a bet
contract.place_bet(user_address, bet_amount);

// To check prize pool
let current_pool = contract.get_prize_pool();

// To check user points
let user_points = contract.get_user_points(user_address);

// To transfer prize (backend only)
contract.transfer_prize(winner_address);
```

