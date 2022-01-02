import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import AssetStorage "mo:asset-storage/AssetStorage";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Order "mo:base/Order";
import Result "mo:base/Result";
import SHA256 "mo:sha/SHA256";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Prim "mo:⛔"; // toLower...

import State "State";

shared({caller = owner}) actor class Assets() : async AssetStorage.Self = {

    private let BATCH_EXPIRY_NANOS = 300_000_000_000;

    stable var stableAuthorized : [Principal]                             = [owner];
    stable var stableAssets     : [(AssetStorage.Key, State.StableAsset)] = [];

    system func preupgrade() {
        stableAuthorized := state.authorized;
        let size = state.assets.size();
        let assets = Array.init<(AssetStorage.Key, State.StableAsset)>(size, (
            "", {
                content_type = "";
                encodings    = [];
            },
        ));

        var i = 0;
        for ((k, a) in state.assets.entries()) {
            assets[i] := (
                k, {
                   content_type = a.content_type;
                   encodings    = Iter.toArray(a.encodings.entries());
                },
            );
            i += 1;
        };
        stableAssets := Array.freeze(assets);
    };

    system func postupgrade() {
        stableAuthorized := [];
        stableAssets     := [];
    };

    var state = State.State(stableAuthorized, stableAssets);
    state.authorized := [owner];

    public shared({caller}) func authorize(p : Principal) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                for (a in state.authorized.vals()) {
                    if (a == p) return;
                };
                state.authorized := Array.append(state.authorized, [p])
            };
        };
    };

    public shared({caller}) func clear(
        a : AssetStorage.ClearArguments,
    ) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                _clear();
            };
        };
    };

    private func _clear() {
        state := State.State(state.authorized, []);
    };

    public shared({caller}) func commit_batch(
        a : AssetStorage.CommitBatchArguments,
    ) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                let batch_id = a.batch_id;
                for (operation in a.operations.vals()) {
                    switch (operation) {
                        case (#Clear(_)) _clear();
                        case (#CreateAsset(a)) {
                            switch (_create_asset(a)) {
                                case (#err(e)) throw Error.reject(e);
                                case (#ok()) {};
                            };
                        };
                        case (#DeleteAsset(a)) _delete_asset(a);
                        case (#SetAssetContent(a)) {
                            switch (_set_asset_content(a)) {
                                case (#err(e)) throw Error.reject(e);
                                case (#ok()) {};
                            };
                        };
                        case (#UnsetAssetContent(a)) {
                            switch (_unset_asset_content(a)) {
                                case (#err(e)) throw Error.reject(e);
                                case (#ok()) {};
                            };
                        };
                    };
                };
            };
        };
    };

    public shared({caller}) func create_asset(
        a : AssetStorage.CreateAssetArguments,
    ) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                switch (_create_asset(a)) {
                    case (#err(e)) throw Error.reject(e);
                    case (#ok()) {};
                };
            };
        };
    };

    private func _create_asset(
        a : AssetStorage.CreateAssetArguments,
    ) : Result.Result<(), Text> {
        switch (state.assets.get(a.key)) {
            case (null) {
                state.assets.put(a.key, {
                    content_type = a.content_type;
                    encodings    = HashMap.HashMap<Text, State.AssetEncoding>(
                        0, Text.equal, Text.hash,
                    );
                });
            };
            case (? asset) {
                if (asset.content_type != a.content_type) {
                    return #err("content type mismatch");
                };
            };
        };
        #ok();
    };

    public shared({caller}) func create_batch({}) : async {
        batch_id : AssetStorage.BatchId
    } {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                let batch_id = state.batchID();
                let now = Time.now();
                state.batches.put(batch_id, {
                    expires_at = now + BATCH_EXPIRY_NANOS;
                });

                // Remove expired batches and chunks.
                for ((k, b) in state.batches.entries()) {
                    if (now > b.expires_at) state.batches.delete(k);
                };
                for ((k, c) in state.chunks.entries()) {
                    switch (state.batches.get(c.batch_id)) {
                        case (null)    { state.chunks.delete(k); };
                        case (? batch) {};
                    };
                };
                { batch_id; };
            };
        };
    };

    public shared({caller}) func create_chunk({
        content  : [Nat8];
        batch_id : AssetStorage.BatchId;
    }) : async {
        chunk_id : AssetStorage.ChunkId
    } {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                switch (state.batches.get(batch_id)) {
                    case (null) throw Error.reject("batch not found: " # Nat.toText(batch_id));
                    case (? batch) {
                        state.batches.put(batch_id, {
                            expires_at = Time.now() + BATCH_EXPIRY_NANOS;
                        });
                        let chunk_id   = state.chunkID();
                        state.chunks.put(chunk_id, {
                            batch_id;
                            content;
                        });
                        { chunk_id; };
                    };
                };
            };
        };
    };

    // Delete an asset by key.
    public shared({caller}) func delete_asset(
        a : AssetStorage.DeleteAssetArguments,
    ) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                _delete_asset(a);
            };
        };
    };

    private func _delete_asset(
        a : AssetStorage.DeleteAssetArguments,
    ) {
        state.assets.delete(a.key);
    };

    public shared query func get({
        key              : AssetStorage.Key;
        accept_encodings : [Text];
    }) : async {
        content          : [Nat8];
        sha256           : ?[Nat8];
        content_type     : Text;
        content_encoding : Text;
        total_length     : Nat;
    } {
        switch (state.assets.get(key)) {
            case (null) throw Error.reject("asset not found: " # key);
            case (? asset) {
                for (e in accept_encodings.vals()) {
                    switch (asset.encodings.get(e)) {
                        case (null) {};
                        case (? encoding) {
                            return {
                                content          = encoding.content_chunks[0];
                                sha256           = ?encoding.sha256;
                                content_type     = asset.content_type;
                                content_encoding = e;
                                total_length     = encoding.total_length;
                            };
                        };
                    }
                };
            };
        };
        throw Error.reject("no matching encoding found: " # debug_show(accept_encodings));
    };

    public shared query({caller}) func get_chunk({
        key              : AssetStorage.Key;
        sha256           : ?[Nat8];
        index            : Nat;
        content_encoding : Text;
    }) : async {
        content : [Nat8];
    } { 
        {content = []};
    };

    public shared query({caller}) func http_request(
        r : AssetStorage.HttpRequest,
    ) : async AssetStorage.HttpResponse {
        let encodings = Buffer.Buffer<Text>(r.headers.size());
        for ((k, v) in r.headers.vals()) {
            if (textToLower(k) == "accept-encoding") {
                for (v in Text.split(v, #text(","))) {
                    encodings.add(v);
                };
            };
        };
        
        encodings.add("identity");
        
        // TODO: url decode + remove path.
        switch (state.assets.get(r.url)) {
            case (null) {};
            case (? asset) {
                for (encoding_name in encodings.vals()) {
                    switch (asset.encodings.get(encoding_name)) {
                        case (null) {};
                        case (? encoding) {
                            let headers = [
                                ("Content-Type", asset.content_type),
                                ("Content-Encoding", encoding_name),
                            ];
                            return {
                                body               = encoding.content_chunks[0];
                                headers;
                                status_code        = 200;
                                streaming_strategy = _create_strategy(
                                    r.url, 0, asset, encoding_name, encoding,
                                );
                            };
                        };
                    };
                };
            };
        };
        {
            body               = Blob.toArray(Text.encodeUtf8("asset not found: " # r.url));
            headers            = [];
            streaming_strategy = null;
            status_code        = 404;
        };
    };

    private func _create_strategy(
        key           : Text,
        index         : Nat,
        asset         : State.Asset,
        encoding_name : Text,
        encoding      : State.AssetEncoding,
    ) : ?AssetStorage.StreamingStrategy {
        switch (_create_token(key, index, asset, encoding_name, encoding)) {
            case (null) { null };
            case (? token) {
                ?#Callback({
                    token;
                    callback = http_request_streaming_callback;
                });
            };
        };
    };

    private func textToLower(t : Text) : Text {
        Text.map(t, Prim.charToLower);
    };

    public shared query({caller}) func http_request_streaming_callback(
        st : AssetStorage.StreamingCallbackToken,
    ) : async AssetStorage.StreamingCallbackHttpResponse {
        switch (state.assets.get(st.key)) {
            case (null) throw Error.reject("key not found: " # st.key);
            case (? asset) {
                switch (asset.encodings.get(st.content_encoding)) {
                    case (null) throw Error.reject("encoding not found: " # st.content_encoding);
                    case (? encoding) {
                        if (st.sha256 != ?encoding.sha256) {
                            throw Error.reject("SHA-256 mismatch");
                        };
                        {
                            token = _create_token(
                                st.key,
                                st.index,
                                asset, 
                                st.content_encoding, 
                                encoding,
                            );
                            body  = encoding.content_chunks[st.index];
                        };
                    };
                };
            };
        };
    };

    private func _create_token(
        key              : Text,
        chunk_index      : Nat,
        asset            : State.Asset,
        content_encoding : Text,
        encoding         : State.AssetEncoding,
    ) : ?AssetStorage.StreamingCallbackToken {
        if (chunk_index + 1 >= encoding.content_chunks.size()) {
            null;
        } else {
            ?{
                key;
                content_encoding;
                index  = chunk_index + 1;
                sha256 = ?encoding.sha256;
            };
        };
    };

    public shared query({caller}) func list({}) : async [AssetStorage.AssetDetails] {
        let details = Buffer.Buffer<AssetStorage.AssetDetails>(state.assets.size());
        for ((key, a) in state.assets.entries()) {
            let encodingsBuffer = Buffer.Buffer<AssetStorage.AssetEncodingDetails>(a.encodings.size());
            for ((n, e) in a.encodings.entries()) {
                encodingsBuffer.add({
                    content_encoding = n;
                    sha256           = ?e.sha256;
                    length           = e.total_length;
                    modified         = e.modified;
                });
            };
            let encodings = Array.sort(encodingsBuffer.toArray(), func(
                a : AssetStorage.AssetEncodingDetails, 
                b : AssetStorage.AssetEncodingDetails,
            ) : Order.Order {
                Text.compare(a.content_encoding, b.content_encoding);
            });
            details.add({
                key;
                content_type = a.content_type;
                encodings;
            });
        };
        details.toArray();
    };

    public shared query({caller}) func retrieve(
        p : AssetStorage.Path,
    ) : async AssetStorage.Contents {
        switch (state.assets.get(p)) {
            case (null) throw Error.reject("asset not found: " # p);
            case (? asset) {
                switch (asset.encodings.get("identity")) {
                    case (null) throw Error.reject("no identity encoding");
                    case (? encoding) {
                        if (encoding.content_chunks.size() > 1) {
                            throw Error.reject("asset too large. use get() or get_chunk() instead");
                        };
                        encoding.content_chunks[0];
                    };
                };
            };
        };
    };

    public shared({caller}) func set_asset_content(
        a : AssetStorage.SetAssetContentArguments,
    ) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                switch (_set_asset_content(a)) {
                    case (#err(e)) throw Error.reject(e);
                    case (#ok()) {};
                };
            };
        };
    };

    private func _set_asset_content(
        a : AssetStorage.SetAssetContentArguments,
    ) : Result.Result<(), Text> {
        if (a.chunk_ids.size() == 0) return #err("must have at least one chunk");
        switch (state.assets.get(a.key)) {
            case (null) #err("asset not found: " # a.key);
            case (? asset) {
                let content_chunks = Buffer.Buffer<[Nat8]>(a.chunk_ids.size());
                for (chunkID in a.chunk_ids.vals()) {
                    switch (state.chunks.get(chunkID)) {
                        case (null) return #err("chunk not found: " # Nat.toText(chunkID));
                        case (? chunk) {
                            content_chunks.add(chunk.content);
                        };
                    };
                };
                for (chunkID in a.chunk_ids.vals()) {
                    state.chunks.delete(chunkID);
                };
                let sha256 = switch (a.sha256) {
                    case (null) {
                        let h = SHA256.Hash(false);
                        for (chunk in content_chunks.vals()) h.write(chunk);
                        h.sum([]);
                    };
                    case (? sha256) {
                        if (sha256.size() != 32) return #err("invalid SHA-25");
                        sha256;
                    };
                };
                var total_length = 0;
                for (chunk in content_chunks.vals()) total_length += chunk.size();

                let encodings = asset.encodings;
                encodings.put(a.content_encoding, {
                    modified       = Time.now();
                    content_chunks = content_chunks.toArray();
                    certified      = false;
                    total_length;
                    sha256;
                });
                state.assets.put(a.key, {
                    content_type = asset.content_type;
                    encodings;
                });
                #ok();
            };
        };
    };

    public shared({caller}) func store(a : {
        key              : AssetStorage.Key;
        content          : [Nat8];
        sha256           : ?[Nat8];
        content_type     : Text;
        content_encoding : Text;
    }) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                let encodings = HashMap.HashMap<Text, State.AssetEncoding>(
                    0, Text.equal, Text.hash,
                );
                let hash = SHA256.sum256(a.content);
                switch (a.sha256) {
                    case (null) {};
                    case (? sha256) {
                        if (hash != sha256) throw Error.reject("SHA-256 mismatch");
                    };
                };
                encodings.put(a.content_encoding, {
                    certified      = false;
                    content_chunks = [a.content];
                    modified       = Time.now();
                    sha256         = hash;
                    total_length   = a.content.size();
                });
                state.assets.put(a.key, {
                    content_type = a.content_type;
                    encodings;
                })
            };
        };
    };

    public shared({caller}) func unset_asset_content(
        a : AssetStorage.UnsetAssetContentArguments,
    ) : async () {
        switch (state.isAuthorized(caller)) {
            case (#err(e)) throw Error.reject(e);
            case (#ok()) {
                switch (_unset_asset_content(a)) {
                    case (#err(e)) throw Error.reject(e);
                    case (#ok()) {};
                };
            };
        };
    };

    private func _unset_asset_content(
        a : AssetStorage.UnsetAssetContentArguments,
    ) : Result.Result<(), Text> {
        switch (state.assets.get(a.key)) {
            case (null) #err("asset not found: " # a.key);
            case (? asset) {
                let encodings = asset.encodings;
                encodings.delete(a.content_encoding);
                state.assets.put(a.key, {
                    content_type = asset.content_type;
                    encodings;
                });
                #ok();
            };
        };
    };
};
