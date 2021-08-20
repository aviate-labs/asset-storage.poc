import AssetStorage "mo:asset-storage/AssetStorage"

actor = {
    public shared func authorize(p : Principal) : async () {
        // TODO
    };

    public shared func clear(a : AssetStorage.ClearArguments) : async () {
        // TODO
    };

    public shared func commit_batch(a : AssetStorage.CommitBatchArguments) : async () {
        // TODO
    };

    public shared func create_asset(a : AssetStorage.CreateAssetArguments) : async () {
        // TODO
    };

    public shared func create_batch() : async {
        batch_id : AssetStorage.BatchId
    } {
        // TODO
        {batch_id = 0 : AssetStorage.BatchId};
    };

    public shared func create_chunk(
        content  : [Nat8], 
        batch_id : AssetStorage.BatchId,
    ) : async {
        chunk_id : AssetStorage.ChunkId
    } {
        // TODO
        {chunk_id = 0 : AssetStorage.ChunkId};
    };

    public shared func delete_asset(a : AssetStorage.DeleteAssetArguments) : async () {
        // TODO
    };

    public shared query func get(
        key              : AssetStorage.Key,
        accept_encodings : [Text],
    ) : async {
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

    public shared query func get_chunk(
        key              : AssetStorage.Key,
        sha256           : ?[Nat8],
        index            : Nat,
        content_encoding : Text,
    ) : async {
        content : [Nat8];
    } {
        // TODO
        {content = []};
    };

    public shared query func http_request(
        r : AssetStorage.HttpRequest,
    ) : async AssetStorage.HttpResponse {
        // TODO
        {
            body               = [];
            headers            = [];
            streaming_strategy = null;
            status_code        = 0;
        };
    };

    public shared query func http_request_streaming_callback(
        st : AssetStorage.StreamingCallbackToken,
    ) : async AssetStorage.StreamingCallbackHttpResponse {
        // TODO
        {
            token = null;
            body  = [];
        };
    };

    public shared query func list() : async [AssetStorage.AssetDetails] {
        // TODO
        [];
    };


    public shared query func retrieve(p : AssetStorage.Path) : async AssetStorage.Contents {
        // TODO
        [];
    };

    public shared func set_asset_content(a : AssetStorage.SetAssetContentArguments) : async () {
        // TODO
    };

    public shared func store(
        key              : AssetStorage.Key,
        content          : [Nat8],
        sha256           : ?[Nat8],
        content_type     : Text,
        content_encoding : Text,
    ) : async () {
        // TODO
    };

    public shared func unset_asset_content(a : AssetStorage.UnsetAssetContentArguments) : async () {
        // TODO
    };
};
