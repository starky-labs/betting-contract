use starknet:: ContractAddress;

trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IBettingContract<TContractState> {
    fn get_prize_pool(self: @TContractState) -> u256;
    fn get_user_points(self: @TContractState, user: ContractAddress) -> u256;
    fn transfer_prize(ref self: TContractState, user: ContractAddress);
    fn place_bet(ref self: TContractState, user: ContractAddress, bet_amount: u256);
    fn claim_winnings(ref self: TContractState, user: ContractAddress);
}

#[starknet::contract]
mod BettingContract {
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    

    #[storage]
    struct Storage {
        prize_pool: u256,
        user_points: Map::<ContractAddress, u256>,
        user_balances: Map::<ContractAddress, u256>,
        contract_address: ContractAddress,
    }

    #[abi(embed_v0)]
    impl BettingContract of super::IBettingContract<ContractState> {
        fn get_prize_pool(self: @ContractState) -> u256 {
            self.prize_pool.read()
        }

        fn get_user_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        fn transfer_prize(ref self: ContractState, user: ContractAddress){
            let pool = self.prize_pool.read();

            let current_balance = self.user_balances.read(user);
            self.user_balances.write(user, current_balance + pool);
            self.prize_pool.write(0.into());
        }

        fn place_bet(ref self: ContractState, user: ContractAddress, bet_amount: u256){
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            let contract_address = self.contract_address.read();

            let erc20_dispatcher = IERC20Dispatcher {contract_address: address};
            erc20_dispatcher.transfer_from(caller, contract_address, bet_amount);
        
            let current_pool = self.prize_pool.read();
            self.prize_pool.write(current_pool + bet_amount);

            let current_points = self.user_points.read(user);
            self.user_points.write(user, current_points + 50);

        }

        fn claim_winnings(ref self: ContractState, user: ContractAddress){
            let caller = get_caller_address();
            let amount = self.user_balances.read(caller);
            let contract_address = get_contract_address();

            let erc20_dispatcher = IERC20Dispatcher {contract_address: address};
            erc20_dispatcher.transfer(caller, amount);

            self.user_balances.write(caller, 0.into());
        }
        
    }
}
