import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import D "mo:base/Debug";
import AssocList "mo:base/AssocList";
import Error "mo:base/Error";
import List "mo:base/List";

import CertTree "mo:cert/CertTree";

import ICRC7 "mo:icrc7-mo";
import ICRC37 "mo:icrc37-mo";
import ICRC3 "mo:icrc3-mo";

import ICRC7Default "./initial_state/icrc7";
import ICRC37Default "./initial_state/icrc37";
import ICRC3Default "./initial_state/icrc3";

shared (_init_msg) actor class Plantify() = this {

    type Account = ICRC7.Account;
    type Environment = ICRC7.Environment;
    type Value = ICRC7.Value;
    type NFT = ICRC7.NFT;
    type NFTShared = ICRC7.NFTShared;
    type NFTMap = ICRC7.NFTMap;
    type OwnerOfResponse = ICRC7.Service.OwnerOfResponse;
    type OwnerOfRequest = ICRC7.Service.OwnerOfRequest;
    type TransferArgs = ICRC7.Service.TransferArg;
    type TransferResult = ICRC7.Service.TransferResult;
    type TransferError = ICRC7.Service.TransferError;
    type BalanceOfRequest = ICRC7.Service.BalanceOfRequest;
    type BalanceOfResponse = ICRC7.Service.BalanceOfResponse;
    type TokenApproval = ICRC37.Service.TokenApproval;
    type CollectionApproval = ICRC37.Service.CollectionApproval;
    type ApprovalInfo = ICRC37.Service.ApprovalInfo;
    type ApproveTokenResult = ICRC37.Service.ApproveTokenResult;
    type ApproveTokenArg = ICRC37.Service.ApproveTokenArg;
    type ApproveCollectionArg = ICRC37.Service.ApproveCollectionArg;
    type IsApprovedArg = ICRC37.Service.IsApprovedArg;

    type ApproveCollectionResult = ICRC37.Service.ApproveCollectionResult;
    type RevokeTokenApprovalArg = ICRC37.Service.RevokeTokenApprovalArg;

    type RevokeCollectionApprovalArg = ICRC37.Service.RevokeCollectionApprovalArg;

    type TransferFromArg = ICRC37.Service.TransferFromArg;
    type TransferFromResult = ICRC37.Service.TransferFromResult;
    type RevokeTokenApprovalResult = ICRC37.Service.RevokeTokenApprovalResult;
    type RevokeCollectionApprovalResult = ICRC37.Service.RevokeCollectionApprovalResult;

    stable var init_msg = _init_msg; //preserves original initialization;

    stable var icrc7_migration_state = ICRC7.init(
        ICRC7.initialState(),
        #v0_1_0(#id),
        ICRC7Default.defaultConfig(init_msg.caller),
        init_msg.caller,
    );

    let #v0_1_0(#data(icrc7_state_current)) = icrc7_migration_state;

    stable var icrc37_migration_state = ICRC37.init(
        ICRC37.initialState(),
        #v0_1_0(#id),
        ICRC37Default.defaultConfig(init_msg.caller),
        init_msg.caller,
    );

    let #v0_1_0(#data(icrc37_state_current)) = icrc37_migration_state;

    stable var icrc3_migration_state = ICRC3.init(
        ICRC3.initialState(),
        #v0_1_0(#id),
        ICRC3Default.defaultConfig(init_msg.caller),
        init_msg.caller,
    );

    let #v0_1_0(#data(icrc3_state_current)) = icrc3_migration_state;

    private var _icrc7 : ?ICRC7.ICRC7 = null;
    private var _icrc37 : ?ICRC37.ICRC37 = null;
    private var _icrc3 : ?ICRC3.ICRC3 = null;

    private func get_icrc7_state() : ICRC7.CurrentState {
        return icrc7_state_current;
    };

    private func get_icrc37_state() : ICRC37.CurrentState {
        return icrc37_state_current;
    };

    private func get_icrc3_state() : ICRC3.CurrentState {
        return icrc3_state_current;
    };

    stable let cert_store : CertTree.Store = CertTree.newStore();
    let ct = CertTree.Ops(cert_store);

    private func get_certificate_store() : CertTree.Store {
        return cert_store;
    };

    private func updated_certification(cert : Blob, lastIndex : Nat) : Bool {
        ct.setCertifiedData();
        return true;
    };

    private func get_icrc3_environment() : ICRC3.Environment {
        ?{
            updated_certification = ?updated_certification;
            get_certificate_store = ?get_certificate_store;
        };
    };

    func ensure_block_types(icrc3Class : ICRC3.ICRC3) : () {
        let supportedBlocks = Buffer.fromIter<ICRC3.BlockType>(icrc3Class.supported_block_types().vals());

        let blockequal = func(a : { block_type : Text }, b : { block_type : Text }) : Bool {
            a.block_type == b.block_type;
        };

        for (thisItem in icrc7().supported_blocktypes().vals()) {
            if (Buffer.indexOf<ICRC3.BlockType>({ block_type = thisItem.0; url = thisItem.1 }, supportedBlocks, blockequal) == null) {
                supportedBlocks.add({
                    block_type = thisItem.0;
                    url = thisItem.1;
                });
            };
        };

        for (thisItem in icrc37().supported_blocktypes().vals()) {
            if (Buffer.indexOf<ICRC3.BlockType>({ block_type = thisItem.0; url = thisItem.1 }, supportedBlocks, blockequal) == null) {
                supportedBlocks.add({
                    block_type = thisItem.0;
                    url = thisItem.1;
                });
            };
        };

        icrc3Class.update_supported_blocks(Buffer.toArray(supportedBlocks));
    };

    func icrc3() : ICRC3.ICRC3 {
        switch (_icrc3) {
            case (null) {
                let initclass : ICRC3.ICRC3 = ICRC3.ICRC3(?icrc3_migration_state, Principal.fromActor(this), get_icrc3_environment());
                _icrc3 := ?initclass;
                ensure_block_types(initclass);

                initclass;
            };
            case (?val) val;
        };
    };

    private func get_icrc7_environment() : ICRC7.Environment {
        {
            canister = get_canister;
            get_time = get_time;
            refresh_state = get_icrc7_state;
            add_ledger_transaction = ?icrc3().add_record;
            can_mint = null;
            can_burn = null;
            can_transfer = null;
            can_update = null;
        };
    };

    private func get_icrc37_environment() : ICRC37.Environment {
        {
            canister = get_canister;
            get_time = get_time;
            refresh_state = get_icrc37_state;
            icrc7 = icrc7();
            can_transfer_from = null;
            can_approve_token = null;
            can_approve_collection = null;
            can_revoke_token_approval = null;
            can_revoke_collection_approval = null;
        };
    };

    func icrc7() : ICRC7.ICRC7 {
        switch (_icrc7) {
            case (null) {
                let initclass : ICRC7.ICRC7 = ICRC7.ICRC7(?icrc7_migration_state, Principal.fromActor(this), get_icrc7_environment());
                _icrc7 := ?initclass;
                initclass;
            };
            case (?val) val;
        };
    };

    func icrc37() : ICRC37.ICRC37 {
        switch (_icrc37) {
            case (null) {
                let initclass : ICRC37.ICRC37 = ICRC37.ICRC37(?icrc37_migration_state, Principal.fromActor(this), get_icrc37_environment());
                _icrc37 := ?initclass;
                initclass;
            };
            case (?val) val;
        };
    };

    private var canister_principal : ?Principal = null;

    private func get_canister() : Principal {
        switch (canister_principal) {
            case (null) {
                canister_principal := ?Principal.fromActor(this);
                Principal.fromActor(this);
            };
            case (?val) {
                val;
            };
        };
    };

    private func get_time() : Int {
        Time.now();
    };

    /*
    ========== Plantify Functionallity ==========
    */
    public type Role = {
        #admin;
        #authorized;
    };

    public type Permission = {
        #mint;
        #transaction;
    };

    public type TokenWithMetadata = {
        id : Nat;
        metadata : [?[(Text, ICRC7.Value)]];
    };

    private stable var roles : AssocList.AssocList<Principal, Role> = List.nil();

    func principal_eq(a : Principal, b : Principal) : Bool {
        return a == b;
    };

    func get_role(pal : Principal) : ?Role {
        if (pal == init_msg.caller) {
            ? #admin;
        } else {
            AssocList.find<Principal, Role>(roles, pal, principal_eq);
        };
    };

    func has_permission(pal : Principal, perm : Permission) : Bool {
        let role = get_role(pal);
        switch (role, perm) {
            case (? #admin, _) true;
            case (? #authorized, #transaction) true;
            case (_, _) false;
        };
    };

    func require_permission(pal : Principal, perm : Permission) : async () {
        if (has_permission(pal, perm) == false) {
            throw Error.reject("unauthorized");
        };
    };

    public shared (msg) func mint(tokens : ICRC7.SetNFTRequest) : async [ICRC7.SetNFTResult] {
        // Only admin / canister controller can mint
        /*
            let caller = msg.caller;
            if (has_permission(caller, #mint)) {
                switch (icrc7().set_nfts<system>(msg.caller, tokens, true)) {
                    case (#ok(val)) val;
                    case (#err(err)) D.trap(err);
                };
            } else {
                throw Error.reject("Cannot mint");
            };
        */

        switch (icrc7().set_nfts<system>(msg.caller, tokens, true)) {
            case (#ok(val)) val;
            case (#err(err)) D.trap(err);
        };
    };

    public query func get_all_paginated_tokens(prev : ?Nat, take : ?Nat) : async [TokenWithMetadata] {
        var tokensWithMetadata = Buffer.Buffer<TokenWithMetadata>(2);

        let tokenIds = icrc7().get_tokens_paginated(prev, take);

        for (tokenId in tokenIds.vals()) {
            let metadata : [?[(Text, ICRC7.Value)]] = icrc7().token_metadata([tokenId]);
            tokensWithMetadata.add({ id = tokenId; metadata = metadata });
        };

        return Buffer.toArray(tokensWithMetadata);
    };

    public shared (msg) func transfer_from<system>(args : [TransferFromArg]) : async [?TransferFromResult] {
        icrc37().transfer_from(msg.caller, args);
    };

    public query func tokens_owner(token_ids : OwnerOfRequest) : async OwnerOfResponse {
        switch (icrc7().get_token_owners(token_ids)) {
            case (#ok(val)) val;
            case (#err(err)) D.trap(err);
        };
    };

    public query func icrc7_tokens_of(account : Account, prev : ?Nat, take : ?Nat) : async [TokenWithMetadata] {
        var tokensWithMetadata = Buffer.Buffer<TokenWithMetadata>(2);

        let tokenIds = icrc7().get_tokens_of_paginated(account, prev, take);

        for (tokenId in tokenIds.vals()) {
            let metadata : [?[(Text, ICRC7.Value)]] = icrc7().token_metadata([tokenId]);
            tokensWithMetadata.add({ id = tokenId; metadata = metadata });
        };

        return Buffer.toArray(tokensWithMetadata);
    };

};
