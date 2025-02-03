
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
        let fee_collector = contract_address_const::<4>();

        let erc20_address = deploy_erc20();
        
       // Deploy betting contract passing erc20 address
        let mut calldata = array![admin.into(), erc20_address.into(), fee_collector.into()];
        let contract = declare("BettingContract").unwrap().contract_class();
        let (contract_address, _) = contract.deploy(@calldata).unwrap();

        // Mint initial balance to the contract (optional)
        let initial_contract_amount: u256 = 1000000000000_u256;
        let mint_dispatcher = IFreeMintDispatcher { contract_address: erc20_address };
        mint_dispatcher.mint(contract_address, initial_contract_amount);

        let initial_amount: u256 = 2000000000000_u256;
        mint_dispatcher.mint(user, initial_amount);

        // Approve spending for the betting contract
        cheat_caller_address(erc20_address, user, CheatSpan::TargetCalls(1));
        let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
        erc20_dispatcher.approve(contract_address, initial_amount);

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
    fn test_place_invalid_bet_amount() {
        let (admin, user, contract_address, mut betting_contract) = setup();
        cheat_caller_address(contract_address, user, CheatSpan::TargetCalls(1));
        
        // Try to place bet with wrong amount
        betting_contract.place_bet(1000000000000_u256);
    }

    #[test]
    fn test_place_bet() {
        let (admin, user, contract, mut betting_contract) = setup();
    
        // Get initial contract balance
        let erc20_address = betting_contract.currency();
        let eth_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
        
        // Get initial prize pool before bet
        let initial_prize_pool = betting_contract.get_prize_pool();
        let initial_contract_balance = eth_dispatcher.balance_of(contract);
    
        // Place bet and verify points
        cheat_caller_address(contract, user, CheatSpan::TargetCalls(1));
        let bet_amount: u256 = 2000000000000_u256;
        betting_contract.place_bet(bet_amount);
        
        let points = betting_contract.get_user_points(user);
        assert(points == 1_u256, 'Points not awarded correctly');
    
        // Calculate expected prize pool
        let fee_amount = (bet_amount * 3_u256) / 100_u256;
        let prize_amount = bet_amount - fee_amount;
        let expected_prize_pool = initial_prize_pool + prize_amount;
    
        // Verify prize pool updated
        let prize_pool = betting_contract.get_prize_pool();
        assert(prize_pool == expected_prize_pool, 'Prize pool not updated');
    }

    #[test]
    fn test_successful_prize_transfer() {
        let (admin, user, contract_address, mut betting_contract) = setup();

        let bet_amount: u256 = 2000000000000_u256;
        
        // Get the ERC20 address that was stored in the betting contract
        let erc20_address = betting_contract.currency();
        let eth_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

        // Track initial balances
        let initial_user_balance = eth_dispatcher.balance_of(user);
        let initial_contract_balance = eth_dispatcher.balance_of(contract_address);
        
        // Get initial prize pool
        let initial_prize_pool = betting_contract.get_prize_pool();
        
        // Place a bet as user
        cheat_caller_address(contract_address, user, CheatSpan::TargetCalls(1));
        betting_contract.place_bet(bet_amount);
        
        // Verify initial prize pool updated
        let updated_prize_pool = betting_contract.get_prize_pool();
        let fee_amount = (bet_amount * 3_u256) / 100_u256;
        let prize_amount = bet_amount - fee_amount;
        let expected_prize_pool = initial_prize_pool + prize_amount;
        
        assert(updated_prize_pool == expected_prize_pool, 'Initial prize pool incorrect');
        
        // Debug: print addresses as felt252
        let admin_felt: felt252 = admin.into();
        let user_felt: felt252 = user.into();
        let contract_felt: felt252 = contract_address.into();
        let erc20_felt: felt252 = erc20_address.into();
        
        println!("Debug Information:");
        println!("Admin Address:             {}", admin_felt);
        println!("User Address:              {}", user_felt);
        println!("Contract Address:          {}", contract_felt);
        println!("ERC20 Address:             {}", erc20_felt);
        println!("Initial User Balance:      {}", initial_user_balance);
        println!("Initial Contract Balance:  {}", initial_contract_balance);
        println!("Updated Prize Pool:        {}", updated_prize_pool);
        
        // Transfer the prize as admin/backend
        cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
        let tx_hash: felt252 = 123;
        
        // Check contract's balance before transfer
        let contract_balance_before = eth_dispatcher.balance_of(contract_address);
        println!("Contract Balance Before Transfer: {}", contract_balance_before);

        betting_contract.transfer_prize(user, tx_hash);
        
        // Verify prize transfer (40% of prize pool)
        let transferred_prize = (updated_prize_pool * 40_u256) / 100_u256;
        let final_prize_pool = betting_contract.get_prize_pool();
        let expected_remaining = updated_prize_pool - transferred_prize;
        
        // Final user balance checks
        let final_user_balance = eth_dispatcher.balance_of(user);
        let expected_final_balance = initial_user_balance + transferred_prize;
        
        println!("Transferred Prize:         {}", transferred_prize);
        println!("Final User Balance:        {}", final_user_balance);
        println!("Expected Final Balance:    {}", expected_final_balance);

        assert(final_prize_pool == expected_remaining, 'Incorrect remaining prize pool');
        assert(final_user_balance == 776000000000_u256, 'Incorrect final balance');
    }

    #[test]
    #[should_panic(expected: ('No prize available',))]
    fn test_transfer_prize_empty_pool() {
        let (admin, user, contract_address, mut betting_contract) = setup();
        
        cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
        let tx_hash: felt252 = 123;
        betting_contract.transfer_prize(user, tx_hash);
    }

    #[test]
    #[should_panic(expected: ('Insufficient balance',))]
    fn test_place_bet_insufficient_balance() {
        let (admin, user, contract_address, mut betting_contract) = setup();

        let insufficient_user = contract_address_const::<5>();
        let erc20_address = betting_contract.currency();

        // Mint less than the required bet amount
        let small_amount: u256 = 1000000000000_u256;
        IFreeMintDispatcher { contract_address: erc20_address }.mint(insufficient_user, small_amount);

        // Try to place a bet with insufficient balance
        cheat_caller_address(contract_address, insufficient_user, CheatSpan::TargetCalls(1));
        betting_contract.place_bet(2000000000000_u256);
    }
  
  

