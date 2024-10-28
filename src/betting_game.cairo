use starknet:: ContractAddress;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


#[starknet::interface]
pub trait IBettingContract<TContractState> {
    fn get_prize_pool(ref self: TContractState) -> u256;
    fn get_user_points(self: @TContractState, user: ContractAddress) -> u256;
    fn place_bet(ref self: TContractState, user: ContractAddress, bet_amount: u256);
}

#[starknet::contract]
mod BettingContract {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BetPlaced: BetPlaced,
    }

    #[derive(Drop, starknet::Event)]
    struct BetPlaced {
        user: ContractAddress,
        amount: u256,
        points_earned: u256,
    }

    #[derive(Drop, Serde, Copy)]
    struct TransferRequest {
    recipient: ContractAddress,
    amount: u256,
}

    #[constructor]
    fn constructor(ref self: ContractState,) {
        let eth_dispatcher = IERC20Dispatcher { 
            contract_address: ETH_ADDRESS.try_into().unwrap() 
        };
        self.prize_pool.write(eth_dispatcher.balance_of(get_contract_address()));
    }

    #[storage]
    struct Storage {
        prize_pool: u256,
        user_points: Map::<ContractAddress, u256>,
    }

    #[abi(embed_v0)]
    impl BettingContract of super::IBettingContract<ContractState> {

        fn get_prize_pool(ref self: ContractState) -> u256 {
            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };
            let current_balance = eth_dispatcher.balance_of(get_contract_address());

            self.prize_pool.write(current_balance);
            current_balance
        }

        fn get_user_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        fn place_bet(ref self: ContractState, user: ContractAddress, bet_amount: u256){
            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };

            // Check if bet amount is greater than 0
            assert(bet_amount > 0_u256, 'Bet amount must be > 0');

            // Check if caller has sufficient balance
            let caller_balance = eth_dispatcher.balance_of(get_caller_address());
            assert(caller_balance >= bet_amount, 'Insufficient balance');

            // Check if contract has sufficient allowance
            let contract_address = get_contract_address();
            let allowance = eth_dispatcher.allowance(get_caller_address(), contract_address);
            assert(allowance >= bet_amount, 'Insufficient allowance');

            eth_dispatcher.transfer_from(get_caller_address(), get_contract_address(), bet_amount );

            let current_balance = eth_dispatcher.balance_of(get_contract_address());
            self.prize_pool.write(current_balance);

            let points_to_add: u256 = 50.into();
            let current_points = self.user_points.read(user);
            self.user_points.write(user, current_points + points_to_add);

            self.emit(BetPlaced { 
                user,
                amount: bet_amount,
                points_earned: points_to_add
            });

        }
        
    }
}


