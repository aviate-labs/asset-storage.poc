import Array "mo:base/Array";
import AssetStorage "mo:asset-storage/AssetStorage";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import SHA256 "mo:sha/SHA256";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Prim "mo:⛔"; // toLower...

import State "State";

shared({caller = owner}) actor class Assets() : async AssetStorage.Self = {

    var state = State.State();
    state.authorized := [owner];

    public shared({caller}) func authorize(p : Principal) : async () {
        // TODO
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
        let authorized = state.authorized;
        state := State.State();
        state.authorized := authorized;
    };

    public shared({caller}) func commit_batch(
        a : AssetStorage.CommitBatchArguments,
    ) : async () {
        // TODO
    };

    public shared({caller}) func create_asset(
        a : AssetStorage.CreateAssetArguments,
    ) : async () {
        // TODO
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
        // TODO
        {batch_id = 0 : AssetStorage.BatchId};
    };

    public shared({caller}) func create_chunk({
        content  : [Nat8];
        batch_id : AssetStorage.BatchId;
    }) : async {
        chunk_id : AssetStorage.ChunkId
    } {
        // TODO
        {chunk_id = 0 : AssetStorage.ChunkId};
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
        // TODO
        {
            content          = [];
            sha256           = null;
            content_type     = "";
            content_encoding = "";
            total_length     = 0;
        };
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
        var encodings : [Text] = [];
        for ((k, v) in r.headers.vals()) {
            if (textToLower(k) == "accept-encoding") {
                for (v in Text.split(v, #text(","))) {
                    encodings := Array.append(encodings, [v]);
                };
            };
        };
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
        // TODO
        [];
    };

    public shared query({caller}) func retrieve(p : AssetStorage.Path) : async AssetStorage.Contents {
        // TODO
        [];
    };

    public shared({caller}) func set_asset_content(
        a : AssetStorage.SetAssetContentArguments,
    ) : async () {
        // TODO
    };

    private func _set_asset_content(
        a : AssetStorage.SetAssetContentArguments,
    ) : Result.Result<(), Text> {
        if (a.chunk_ids.size() == 0) return #err("must have at least one chunk");
        switch (state.assets.get(a.key)) {
            case (null) #err("asset not found: " # a.key);
            case (? asset) {
                let now = Time.now();
                var content_chunks : [[Nat8]] = [];
                for (chunkID in a.chunk_ids.vals()) {
                    switch (state.chunks.get(chunkID)) {
                        case (null) return #err("chunk not found: " # Nat.toText(chunkID));
                        case (? chunk) {
                            content_chunks := Array.append<[Nat8]>(content_chunks, [chunk.content]);
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
                    modified = now;
                    content_chunks;
                    certified = false;
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

    public shared({caller}) func store(asset : {
        key              : AssetStorage.Key;
        content          : [Nat8];
        sha256           : ?[Nat8];
        content_type     : Text;
        content_encoding : Text;
    }) : async () {
        // TODO
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
