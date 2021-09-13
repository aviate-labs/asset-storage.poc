import AssetStorage "../src/AssetStorage";

func forEachDo(
    // For every token in the given streaming strategy...
    strategy : AssetStorage.StreamingStrategy,
    // Do the following...
    f        : (index : Nat, body : [Nat8]) -> (),
) : async () {
    let (init, callback) = switch (strategy) {
        case (#Callback(v)) (v.token, v.callback);
    };
    var token = ?init;
    loop {
        switch (token) {
            case (null) { return; };
            case (? tk) {
                let resp = await callback(tk);
                f(tk.index, resp.body);
                token := resp.token;
            };
        };
    };
};

var i = 0;
forEachDo(
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