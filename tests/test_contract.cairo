
    use betting_game::betting_game::{BettingContract, IBettingContract, IBettingContractDispatcher, IBettingContractDispatcherTrait};
    use starknet::{SyscallResultTrait, syscalls::deploy_syscall};
    use snforge_std::{declare, cheat_caller_address, CheatSpan, ContractClassTrait, DeclareResultTrait};
   
    use starknet::{
        ContractAddress,
        contract_address_const,
        testing::set_contract_address,
        testing::set_caller_address
    };

    use openzeppelin_token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};

    //mock erc20
    #[starknet::interface]
    trait IFreeMint<T> {
        fn mint(ref self: T, recipient: ContractAddress, amount: u256);
    }

    #[starknet::contract]
    mod FreeMintERC20 {
        use openzeppelin_token::erc20::ERC20Component;
        use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
        use starknet::ContractAddress;
        use super::IFreeMint;

        component!(path: ERC20Component, storage: erc20, event: ERC20Event);

        #[abi(embed_v0)]
        impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
        #[abi(embed_v0)]
        impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
        #[abi(embed_v0)]
        impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
        impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

        #[storage]
        struct Storage {
            #[substorage(v0)]
            erc20: ERC20Component::Storage
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            #[flat]
            ERC20Event: ERC20Component::Event
        }

        #[constructor]
        fn constructor(
            ref self: ContractState,
            initial_supply: u256,
            name: core::byte_array::ByteArray,
            symbol: core::byte_array::ByteArray
        ) {
            self.erc20.initializer(name, symbol);
        }

        #[abi(embed_v0)]
        impl ImplFreeMint of IFreeMint<ContractState> {
            fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
                self.erc20.mint(recipient, amount);
            }
        }
    }

    fn deploy_erc20() -> ContractAddress {
        let contract = declare("FreeMintERC20").unwrap().contract_class();
        let initial_supply: u256 = 10_000_000_000_u256;
        let name: ByteArray = "DummyERC20";
        let symbol: ByteArray = "DUMMY";
    
        let mut calldata: Array<felt252> = array![];
        initial_supply.serialize(ref calldata);
        name.serialize(ref calldata);
        symbol.serialize(ref calldata);
        let (erc20_address, _) = contract.deploy(@calldata).unwrap();
        erc20_address
    }

    fn setup() -> (ContractAddress, ContractAddress, ContractAddress, IBettingContractDispatcher) {
        let admin = contract_address_const::<1>();
        let user = contract_address_const::<2>();
        let contract = contract_address_const::<3>();

        //deploy erc20 contract
        let erc20_address = deploy_erc20();


        
        // Deploy contract passing erc20
        let mut calldata = array![admin.into(), erc20_address.into()];
        let contract = declare("BettingContract").unwrap().contract_class();

        let (contract_address, _) = contract.deploy(@calldata).unwrap();

        IFreeMintDispatcher { contract_address:erc20_address}.mint(user,2000);

        cheat_caller_address(erc20_address, user, CheatSpan::TargetCalls(1));
        IERC20Dispatcher {contract_address:erc20_address}.approve(contract_address, 2000 );

        let dispatcher = IBettingContractDispatcher { contract_address };
        
        (admin, user, contract_address, dispatcher)
    }

    #[test]
    #[should_panic]
    fn test_transfer_prize_unauthorized() {
        let (admin, user, contract_address, mut betting_contract) = setup();
        cheat_caller_address(contract_address,user, CheatSpan::TargetCalls(1));

        let tx_hash: felt252 = 123;
        
        betting_contract.transfer_prize(user, tx_hash);
    }

    #[test]
    #[should_panic]
    fn test_place_zero_bet() {
        let (admin, user, _, mut betting_contract) = setup();
        
        betting_contract.place_bet(0_u256)
    }

    #[test]
    fn test_sucessuful_bet() {
        let (admin, user, contract, mut betting_contract) = setup();
        // Place bet and verify points
        cheat_caller_address(contract,user, CheatSpan::TargetCalls(1));
        betting_contract.place_bet(100_u256);
        
        let points = betting_contract.get_user_points(user);
        assert(points == 1_u256, 'Points not awarded correctly');

        // Verify prize pool updated
        let prize_pool = betting_contract.get_prize_pool();
        assert(prize_pool == 100_u256 ,'Prize pool not updated');
    }

    #[test]
    fn test_successful_prize_transfer() {
        let (admin, user, contract_address, mut betting_contract) = setup();
    
        // Get the ERC20 address from the setup
        let erc20_address = deploy_erc20();
        
        let initial_balance = IERC20Dispatcher { contract_address: erc20_address }.balance_of(user);
        
        // Place a bet to have something in the prize pool
        cheat_caller_address(contract_address, user, CheatSpan::TargetCalls(1));
        let bet_amount: u256 = 100_u256;
        betting_contract.place_bet(bet_amount);
    
        // Verify initial prize pool
        let initial_prize_pool = betting_contract.get_prize_pool();
        assert(initial_prize_pool == bet_amount, 'Initial prize pool incorrect');
        
        // Transfer the prize as admin/backend
        cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
        let tx_hash: felt252 = 123;
        betting_contract.transfer_prize(user, tx_hash);
    
        let final_prize_pool = betting_contract.get_prize_pool();
        assert(final_prize_pool == 0_u256, 'Prize pool should be empty');
        
        // Verify user received the funds
        let eth_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
        let final_balance = eth_dispatcher.balance_of(user);
        
        // Final balance should be: initial balance (2000) - bet amount (100) + prize amount (100)
        // In this case, it should equal the initial balance since we're getting back what we bet
        assert(final_balance == initial_balance, 'User should have received prize');
    }

    #[test]
    #[should_panic(expected: ('No prize available',))]
    fn test_transfer_prize_empty_pool() {
        let (admin, user, contract_address, mut betting_contract) = setup();
        
        // Try to transfer prize when pool is empty
        cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
        let tx_hash: felt252 = 123;
        betting_contract.transfer_prize(user, tx_hash);
    }

    #[test]
    #[should_panic(expected: ('Insufficient balance',))]
    fn test_place_bet_insufficient_balance() {
        let (admin, user, contract_address, mut betting_contract) = setup();
        
        cheat_caller_address(contract_address, user, CheatSpan::TargetCalls(1));
        betting_contract.place_bet(3000_u256); 
    }
  
  

