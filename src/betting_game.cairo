use starknet:: ContractAddress;

#[starknet::interface]
pub trait IBettingContract<TContractState> {
    fn get_prize_pool(self: @TContractState) -> u256;
    fn get_user_points(self: @TContractState, user: ContractAddress) -> u256;
    fn place_bet(ref self: TContractState, bet_amount: u256);
    fn transfer_prize(ref self: TContractState, user: ContractAddress, tx_hash: felt252);
    fn currency(self: @TContractState) -> ContractAddress;
    fn fee_collector_address(self: @TContractState) -> ContractAddress;

}

#[starknet::contract]
pub mod BettingContract {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BetPlaced: BetPlaced,
        PrizeTransferred: PrizeTransferred,
        PlatformFeeCollected: PlatformFeeCollected
    }

    #[derive(Drop, starknet::Event)]
    struct BetPlaced {
        user: ContractAddress,
        amount: u256,
        points_earned: u256,
        fee_amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct PrizeTransferred {
        user: ContractAddress,
        amount: u256,
        timestamp: u64,
        tx_hash: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct PlatformFeeCollected {
        fee_collector: ContractAddress,
        amount: u256
    }

    #[storage]
    struct Storage {
        prize_pool: u256,
        user_points: Map::<ContractAddress, u256>,
        backend_address: ContractAddress,
        currency:ContractAddress,
        required_bet_amount: u256,
        fee_collector_address: ContractAddress,
        platform_fee_percentage: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState,initial_backend_address: ContractAddress, currency: ContractAddress, fee_collector_address: ContractAddress) {
        self.backend_address.write(initial_backend_address);
        self.currency.write(currency);
        self.required_bet_amount.write(2000000000000_u256);
        self.fee_collector_address.write(fee_collector_address);
        self.platform_fee_percentage.write(3_u256);

        let eth_dispatcher = IERC20Dispatcher { 
            contract_address: currency 
        };
        self.prize_pool.write(eth_dispatcher.balance_of(get_contract_address()));
    }

      // Internal function to check if caller is the backend and fee calculation
     #[generate_trait]
     impl InternalFunctions of InternalFunctionsTrait {
        fn assert_only_backend(self: @ContractState) {
            let caller = get_caller_address();
            let backend = self.backend_address.read();
            assert(caller == backend, 'Only backend can call this');
        }

        fn calculate_fee_amount(self: @ContractState, amount: u256) -> u256 {
            (amount * self.platform_fee_percentage.read()) / 100_u256
        }
     }

    #[abi(embed_v0)]
    impl BettingContract of super::IBettingContract<ContractState> {

        fn currency(self: @ContractState) -> ContractAddress {
            self.currency.read()
        }

        fn fee_collector_address(self: @ContractState) -> ContractAddress {
            self.fee_collector_address.read()
        }


        fn get_prize_pool(self: @ContractState) -> u256 {
          self.prize_pool.read()
        }

        fn get_user_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        fn transfer_prize(ref self: ContractState, user: ContractAddress, tx_hash: felt252) {
            InternalFunctions::assert_only_backend(@self);

            let prize_pool = self.prize_pool.read();
            assert(prize_pool > 0_u256, 'No prize available');

            let transfer_amount = (prize_pool * 70_u256) / 100_u256;

            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: self.currency.read()
            };

            eth_dispatcher.transfer(user, transfer_amount);

            let remaining_amount = prize_pool - transfer_amount;
            self.prize_pool.write(remaining_amount);

            self.emit(PrizeTransferred { 
                user,
                amount: transfer_amount,
                timestamp: starknet::get_block_timestamp(),
                tx_hash
            });
        }

        fn place_bet(ref self: ContractState, bet_amount: u256){
            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: self.currency.read() 
            };

            let required_amount = self.required_bet_amount.read();
            assert(bet_amount == required_amount, 'Invalid bet amount');

            let caller_address = get_caller_address();
            let caller_balance = eth_dispatcher.balance_of(caller_address);
           
            assert(caller_balance >= bet_amount, 'Insufficient balance');

            let contract_address = get_contract_address();
            eth_dispatcher.transfer_from(caller_address, contract_address, bet_amount );

            let fee_amount = InternalFunctions::calculate_fee_amount(@self, bet_amount);
            let fee_collector = self.fee_collector_address.read();
            eth_dispatcher.transfer(fee_collector, fee_amount);

            let prize_amount = bet_amount - fee_amount;
            self.prize_pool.write(self.prize_pool.read() + prize_amount);

            let points_to_add: u256 = 1.into();
            let current_points = self.user_points.read(caller_address);
            self.user_points.write(caller_address, current_points + points_to_add);

            self.emit(BetPlaced { 
                user:caller_address,
                amount: bet_amount,
                points_earned: points_to_add,
                fee_amount
            });

            self.emit(PlatformFeeCollected {
                fee_collector,
                amount: fee_amount
            });
        }
        
    }
}


