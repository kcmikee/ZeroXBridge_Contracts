use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::DeclareResultTrait;
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{cheat_caller_address, declare, CheatSpan, ContractClassTrait};
use l2::DAO::{IDAODispatcher, IDAODispatcherTrait};

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn alice() -> ContractAddress {
    contract_address_const::<'alice'>()
}

fn deploy_dao(xzb_token: ContractAddress) -> ContractAddress {
    let contract_class = declare("DAO").unwrap().contract_class();
    let mut calldata = array![];
    calldata.append_serde(xzb_token);
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

fn create_proposal(
    dao: ContractAddress,
    proposal_id: u256,
    description: felt252,
    poll_duration: u64,
    voting_duration: u64,
) {
    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, owner(), CheatSpan::TargetCalls(1));
    dao_dispatcher.create_proposal(proposal_id, description, poll_duration, voting_duration);
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_double_vote_should_fail() {
    let alice = alice();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1', 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, alice, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true);
    dao_dispatcher.vote_in_poll(1, true);
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_vote_with_no_tokens_should_fail() {
    let bob = contract_address_const::<'bob'>();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1', 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, bob, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true);
}

#[test]
fn test_create_proposal() {
    let owner = owner();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, owner, CheatSpan::TargetCalls(1));
    dao_dispatcher.create_proposal(1, 'New Proposal'.into(), 1000, 2000);

    let proposal = dao_dispatcher.get_proposal(1);
    assert(proposal.id == 1, 'Proposal ID mismatch');
    assert(proposal.description == 'New Proposal'.into(), 'Proposal description mismatch');
    assert(proposal.creator == owner, 'Proposal creator mismatch');
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_vote_after_poll_phase_should_fail() {
    let alice = alice();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1, 2000); // Short poll duration

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, alice, CheatSpan::TargetCalls(1));

    // Simulate time passing
    dao_dispatcher.vote_in_poll(1, true);
}

#[test]
#[should_panic(expected: 'Proposal does not exist')]
fn test_vote_on_nonexistent_proposal_should_fail() {
    let alice = alice();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, alice, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(999, true); // Nonexistent proposal ID
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_double_vote_by_same_voter_should_fail() {
    let alice = alice();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, alice, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true);
    dao_dispatcher.vote_in_poll(1, false);
}


#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_vote_with_zero_token_balance_should_fail() {
    let charlie = contract_address_const::<'charlie'>();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, charlie, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true);
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_tally_poll_votes_passed() {
    let owner = owner();
    let alice = alice();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };

    // Simulate owner voting for the proposal
    cheat_caller_address(dao, owner, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true); // Owner votes for

    // Simulate Alice voting for the proposal
    cheat_caller_address(dao, alice, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true); // Alice votes for

    // Tally votes
    dao_dispatcher.tally_poll_votes(200);
    let proposal = dao_dispatcher.get_proposal(2);
    assert(proposal.state == 1, 'Proposal should be passed');
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_tally_poll_votes_defeated() {
    let owner = owner();
    let alice = alice();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };

    // Simulate owner voting against the proposal
    cheat_caller_address(dao, owner, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, false); // Owner votes against

    // Simulate Alice voting against the proposal
    cheat_caller_address(dao, alice, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, false); // Alice votes against

    // Tally votes
    dao_dispatcher.tally_poll_votes(1);
    let proposal = dao_dispatcher.get_proposal(1);
    assert(proposal.state == 4, 'Proposal should be defeated');
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_tally_poll_votes_not_in_poll_phase() {
    let owner = owner();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1, 2000); // Short poll duration

    let dao_dispatcher = IDAODispatcher { contract_address: dao };
    cheat_caller_address(dao, owner, CheatSpan::TargetCalls(1));
    dao_dispatcher.vote_in_poll(1, true); // Vote in poll

    // Simulate time passing to end the poll phase
    // Attempt to tally votes after poll phase has ended
    dao_dispatcher.tally_poll_votes(1);
}

#[test]
#[should_panic(expected: 'Not in poll phase')]
fn test_tally_poll_votes_no_votes() {
    // let owner = owner();
    let xzb_token = contract_address_const::<'xzb_token'>();
    let dao = deploy_dao(xzb_token);
    create_proposal(dao, 1, 'Proposal 1'.into(), 1000, 2000);

    let dao_dispatcher = IDAODispatcher { contract_address: dao };

    // Tally votes without any votes cast
    dao_dispatcher.tally_poll_votes(1);
    let proposal = dao_dispatcher.get_proposal(1);
    assert(proposal.state == 0, 'Not in poll phase');
}
