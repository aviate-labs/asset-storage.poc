import AssetStorage "mo:asset-storage/AssetStorage";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Text "mo:base/Text";

module {
    public type Asset = {
        content_type : Text;
        encodings: HashMap.HashMap<Text, AssetEncoding>;
    };

    public type AssetEncoding = {
        modified       : Int;
        content_chunks : [[Nat8]];
        total_length   : Nat;
        certified      : Bool;
        sha256         : [Nat8];
    };

    public type Chunk = {
        batch_id : AssetStorage.BatchId;
        content  : [Nat8];
    };

    public type Batch = {
        expires_at : Int;
    };

    public class State() {
        public let assets = HashMap.HashMap<AssetStorage.Key, Asset>(
            0, Text.equal, Text.hash,
        );

        public let chunks = HashMap.HashMap<AssetStorage.ChunkId, Chunk>(
            0, Nat.equal, Hash.hash,
        );

        var nextChunkID : AssetStorage.ChunkId = 1;

        public func chunkId() : AssetStorage.ChunkId {
            let cID = nextChunkID;
            nextChunkID += 1;
            cID;
        };

        public let batches = HashMap.HashMap<AssetStorage.BatchId, Batch>(
            0, Nat.equal, Hash.hash,
        );

        var nextBatchID : AssetStorage.BatchId = 1;

        public func batchID() : AssetStorage.BatchId {
            let bID = nextBatchID;
            nextBatchID += 1;
            bID;
        };

        public var authorized : [Principal] = [];

        public func isAuthorized(p : Principal) : Result.Result<(), Text> {
            for (a in authorized.vals()) {
                if (a == p) return #ok();
            };
            #err("caller is not authorized");
        };
    };
};
