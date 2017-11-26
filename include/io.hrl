-define(JS,    (application:get_env(bert,js,   "json-bert.js"))).
-define(JAVA,  (application:get_env(bert,java, "Decoder.swift"))).
-define(SWIFT, (application:get_env(bert,swift,"java.java"))).

-record(error, {code=[] :: [] | binary()}).
-record(ok,    {code=[] :: [] | binary()}).
-record(io,    {code=[] :: [] | #ok{} | #error{},
                data=[] :: [] | <<>> | {atom(),binary()|integer()}}).
