import AssetStorage "../src/AssetStorage";
import Streaming "../src/Streaming";

var i = 0;
Streaming.forEachDo(
    #Callback({
        token = {
            key              = "";
            sha256           = null;
            index            = 0;
            content_encoding = "";
        };
        callback = shared query func (s : AssetStorage.StreamingCallbackToken) : async AssetStorage.StreamingCallbackHttpResponse {
            if (s.index < 9) {
                return {
                    token = ?{
                        key              = s.key;
                        sha256           = s.sha256;
                        index            = s.index + 1;
                        content_encoding = s.content_encoding;
                    };
                    body  = [];
                };
            };
            {
                token = null;
                body  = [];
            };
        };
    }),
    func (index : Nat, _ : [Nat8]) {
        assert(index == i);
        assert(index < 10);
        i += 1;
    },
);