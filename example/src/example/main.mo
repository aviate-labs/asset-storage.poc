import Blob "mo:base/Blob";
import Text "mo:base/Text";

import AssetStorage "mo:asset-storage/AssetStorage";

actor = {
    public shared query func http_request(
        r : AssetStorage.HttpRequest,
    ) : async AssetStorage.HttpResponse {
        {
            body               = Blob.toArray(
                Text.encodeUtf8("<h1>Hello world!</h1>"),
            );
            headers            = [("Content-Type", "text/html; charset=UTF-8")];
            streaming_strategy = null;
            status_code        = 200;
        };
    };
};
