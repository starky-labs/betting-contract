use starknet:: ContractAddress;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


#[starknet::interface]
pub trait IBettingContract<TContractState> {
    fn get_prize_pool(self: @TContractState) -> u256;
    fn get_user_points(self: @TContractState, user: ContractAddress) -> u256;
    fn update_prize(ref self: TContractState);
    fn place_bet(ref self: TContractState, user: ContractAddress, bet_amount: u256);
}

#[starknet::contract]
mod BettingContract {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

    #[derive(Drop, Serde, Copy)]
    struct TransferRequest {
    recipient: ContractAddress,
    amount: u256,
}

    #[constructor]
    fn constructor(ref self: ContractState,) {}

    #[storage]
    struct Storage {
        prize_pool: u256,
        user_points: Map::<ContractAddress, u256>,
        user_balances: Map::<ContractAddress, u256>,
        token_address: ContractAddress,
    }

    #[abi(embed_v0)]
    impl BettingContract of super::IBettingContract<ContractState> {
        fn get_prize_pool(self: @ContractState) -> u256 {
            self.prize_pool.read()
        }

        fn get_user_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        fn update_prize(ref self: ContractState){
         self.prize_pool.write(0.into());
        }

        fn place_bet(ref self: ContractState, user: ContractAddress, bet_amount: u256){
        
            let current_pool = self.prize_pool.read();
            self.prize_pool.write(current_pool + bet_amount);

            let eth_dispatcher = IERC20Dispatcher { 
                contract_address: ETH_ADDRESS.try_into().unwrap() 
            };
            eth_dispatcher.transfer_from(get_caller_address(), get_contract_address(), bet_amount );

            let current_points = self.user_points.read(user);
            self.user_points.write(user, current_points + 50);

        }
        
    }
}
