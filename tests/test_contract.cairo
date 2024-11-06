
#[cfg(test)]
mod tests {
    use super::{BettingContract, IBettingContract, IBettingContractDispatcher};
    use starknet::{SyscallResultTrait, syscalls::deploy_syscall};
   
    use starknet::{
        ContractAddress,
        get_contract_address,
        contract_address_const,
        get_block_timestamp,
        set_block_timestamp,
        get_caller_address,
        testing::set_contract_address,
        testing::set_caller_address
    };

    use openzeppelin_token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};

    // Mock ERC20 contract
    #[starknet::contract]
    mod MockERC20 {
        use starknet::ContractAddress;
        use starknet::storage::Map;

        #[storage]
        struct Storage {
            balances: Map::<ContractAddress, u256>,
            allowances: Map::<(ContractAddress, ContractAddress), u256>,
        }

        #[external(v0)]
        impl IERC20 of super::IERC20<ContractState> {
            fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
                true
            }
            fn transfer_from(
                ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
            ) -> bool {
                true
            }
            fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
                true
            }
            fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
                1000_u256
            }
            fn allowance(
                self: @ContractState, owner: ContractAddress, spender: ContractAddress
            ) -> u256 {
                1000_u256
            }
        }
    }

    fn setup() -> (ContractAddress, ContractAddress, ContractAddress, BettingContract::ContractState) {
        let admin = contract_address_const::<1>();
        let user = contract_address_const::<2>();
        let contract = contract_address_const::<3>();
        
        set_contract_address(contract);

        // Deploy contract
        let mut calldata = array![admin.into()];
        let (contract_address, _) = deploy_syscall(
            BettingContract::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            calldata.span(),
            false
        ).unwrap();

        let dispatcher = IBettingContractDispatcher { contract_address };
        
        (admin, user, contract, betting_contract)
    }

    #[test]
    #[should_panic]
    fn test_transfer_prize_unauthorized() {
        let (admin, user, contract, mut betting_contract) = setup();
        set_caller_address(user);
        
        contract_dispatcher.transfer_prize(user);
    }

    #[test]
    #[should_panic]
    fn test_place_zero_bet() {
        let (admin, user, contract, mut betting_contract) = setup();
        
        contract_dispatcher.place_bet(user, 0_u256);
    }

    #[test]
    fn test_sucessuful_bet() {
        let (admin, user, contract, mut betting_contract) = setup();
    // Place bet and verify points
    dispatcher.place_bet(user, 100_u256);
    let points = dispatcher.get_user_points(user);
    assert(points == 50_u256, 'Points not awarded correctly');

    // Verify prize pool updated
    let prize_pool = dispatcher.get_prize_pool();
    assert(prize_pool == 1000_u256, 'Prize pool not updated');
    }

    #[test]
    fn test_approve_betting_amount() {
        let (admin, user, contract_address, dispatcher) = setup();
        
        set_caller_address(user);
        let result = dispatcher.approve_betting_amount(500_u256);
        assert(result == true, 'Approval failed');
        
        let allowance = dispatcher.get_remaining_allowance();
        assert(allowance == 1000_u256, 'Incorrect allowance');
    }
    #[test]
    #[available_gas(150000)]
    fn test_deploy_gas() {
        deploy(10);
    }

}