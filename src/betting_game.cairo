use starknet:: ContractAddress;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


#[starknet::interface]
pub trait IBettingContract<TContractState> {
    fn get_prize_pool(self: @TContractState) -> u256;
    fn get_user_points(self: @TContractState, user: ContractAddress) -> u256;
    fn place_bet(ref self: TContractState, user: ContractAddress, bet_amount: u256);
    fn transfer_prize(ref self: TContractState, user: ContractAddress);
    fn approve_betting_amount(ref self: TContractState, amount: u256) -> bool;
    fn get_remaining_allowance(self: @TContractState) -> u256;
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
        BettingApproved: BettingApproved,
        PrizeTransferred: PrizeTransferred
    }

    #[derive(Drop, starknet::Event)]
    struct BetPlaced {
        user: ContractAddress,
        amount: u256,
        points_earned: u256,
        remaining_allowance: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BettingApproved {
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PrizeTransferred {
        user: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[storage]
    struct Storage {
        prize_pool: u256,
        user_points: Map::<ContractAddress, u256>,
        backend_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState,initial_backend_address: ContractAddress ) {
        self.backend_address.write(initial_backend_address);

        let eth_dispatcher = IERC20Dispatcher { 
            contract_address: ETH_ADDRESS.try_into().unwrap() 
        };
        self.prize_pool.write(eth_dispatcher.balance_of(get_contract_address()));
    }

      // Internal function to check if caller is the backend
     #[generate_trait]
     impl InternalFunctions of InternalFunctionsTrait {
        fn assert_only_backend(self: @ContractState) {
            let caller = get_caller_address();
            let backend = self.backend_address.read();
            assert(caller == backend, 'Only backend can call this');
        }
     }

    #[abi(embed_v0)]
    impl BettingContract of super::IBettingContract<ContractState> {
        
        fn approve_betting_amount(ref self: ContractState, amount: u256) -> bool {
            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };
            
            let approve = eth_dispatcher.approve(get_contract_address(), amount);
            
            self.emit(BettingApproved { 
                user: get_caller_address(),
                amount
            });
            
            approve
        }

        fn get_remaining_allowance(self: @ContractState) -> u256 {
            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };
            eth_dispatcher.allowance(get_caller_address(), get_contract_address())
        }

        fn get_prize_pool(self: @ContractState) -> u256 {
          self.prize_pool.read()
        }


        fn get_user_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        fn transfer_prize(ref self: ContractState, user: ContractAddress) {
            InternalFunctions::assert_only_backend(@self);

            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };
            
            let prize_pool = eth_dispatcher.balance_of(get_contract_address());
            assert(prize_pool > 0_u256, 'No prize available');
            eth_dispatcher.transfer(user, prize_pool);

            self.emit(PrizeTransferred { 
                user,
                amount: prize_pool,
                timestamp: starknet::get_block_timestamp()
            });
        }

        fn place_bet(ref self: ContractState, user: ContractAddress, bet_amount: u256){
            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };

            assert(bet_amount > 0_u256, 'Bet amount must be > 0');

            let caller_balance = eth_dispatcher.balance_of(get_caller_address());
            println!("{}", caller_balance);
            assert(caller_balance.low > bet_amount.low, 'Insufficient balance');

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

            // Get updated allowance after bet
            let remaining_allowance = eth_dispatcher.allowance(get_caller_address(), contract_address);

            self.emit(BetPlaced { 
                user,
                amount: bet_amount,
                points_earned: points_to_add,
                remaining_allowance
            });

        }
        
    }
}


