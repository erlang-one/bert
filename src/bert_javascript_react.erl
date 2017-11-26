-module(bert_javascript_react).
-export([parse_transform/2]).
-compile(export_all).
-include("io.hrl").

parse_transform(Forms, _Options) ->
    io:format("Generated JavaScript (React): ~p~n",[?JS]),
    file:write_file(?JS,directives(Forms)), Forms.

directives(Forms) -> iolist_to_binary([prelude(), [ form(F) || F <- Forms ], culmination()]).

form({attribute,_,record,{List,T}}) -> [decoder(List,T), encoder(List,T)];
form(Form) ->  [].

prelude()  -> string:join([
    "'use strict'\n",
    "import { bert, utf8 } from 'react-n2o'\n",
    "let jsonBert = {",
    "    info: (r) => (r.t === 104 && r.v && r.v[0] && r.v[0].t === 100 && r.v[0].v) ? {tup: r.v[0].v, len: r.v.length} : {},",
    "    check: (r,arr) => {",
    "        let {tup, len} = jsonBert.info(r)",
    "        for(let i = 0; i < arr.length; i++) {",
    "            let [n,l = len, meta] = arr[i]; if(tup === n && len === l) return {tup, len, meta} }",
    "        return false",
    "    },",
    "    clean: (r) => { for(var k in r) if(!r[k]) delete r[k]; return r },",
    "    check_len: (x) => { try {",
    "        return jsonBert[utf8.dec(x.v[0].v)].len === x.v.length",
    "    } catch (e) { return false } },",
    "    scalar: (data) => { switch (typeof data) {",
    "        case 'string': return bert.bin(data)",
    "        case 'number': return bert.number(data)",
    "        default: console.log('Strange data: ' + data)",
    "        return undefined",
    "    } },",
    "    nil: () => ({t: 106, v: undefined}),",
    "    decode: (x) => {",
    "        if(x === undefined) return []",
    "        switch (x.t) {",
    "            case 108: return x.v.map(jsonBert.decode)",
    "            case 109: return utf8.dec(x.v)",
    "            case 104: if(jsonBert.check_len(x)) { return jsonBert[utf8.dec(x.v[0].v)].dec(x) }",
    "                return Object.assign({tup:'$'}, x.v.map(jsonBert.decode))",
    "        }",
    "        return x.v",
    "    },",
    "    encode: (x) => {",
    "        if (Array.isArray(x)) { return {t:108, v:x.map(jsonBert.encode)} }",
    "        else if (typeof x === 'object') { switch (x.tup) {",
    "        	case '$':",
    "                delete x['tup']",
    "            	return {t:104, v:Object.values(x).map(jsonBert.encode)}",
    "            default: return jsonBert[x.tup].enc(x)",
    "        } }",
    "        return jsonBert.scalar(x)",
    "    },\n\n    /// Auto generated\n\n"
    ],"\n").
    
culmination() -> "}\n\nexport default jsonBert".

case_fields(Forms,Prefix) ->
    string:join([ case_field(F,Prefix) || F <- Forms, case_field(F,Prefix) /= []],";\n\t").
case_field({attribute,_,record,{List,T}},Prefix) ->
    lists:concat(["case '",List,"': return ",Prefix,List,"(x); break"]);
case_field(Form,_) ->  [].

decoder(List,T) ->
   L = nitro:to_list(List),
   Fields =  [{ lists:concat([Field]), {Name,Args}}
          || {_,{_,_,{atom,_,Field},Value},{type,_,Name,Args}} <- T ],
   case Fields of [] -> []; _ ->
   iolist_to_binary(["    '",L,"': { len: ",integer_to_list(1+length(Fields)),",\n"
                     "        dec: (d) => jsonBert.clean({\n            tup: '",L,"',\n            ",
                     string:join([ dispatch_dec(Type,Name,I) ||
     {{Name,Type},I} <- lists:zip(Fields,lists:seq(1,length(Fields))) ],",\n            "),
     "}),\n"]) end.

encoder(List,T) ->
   Class = nitro:to_list(List),
   Fields =  [{ lists:concat([Field]), {Name,Args}}
          || {_,{_,_,{atom,_,Field},Value},{type,_,Name,Args}} <- T ],
   Names = element(1,lists:unzip(Fields)),
   StrNames = case length(Fields) < 12 of
                   true  -> string:join(Names,",");
                   false -> {L,R} = lists:split(10,Names),
                            string:join(L,",") ++ ",\n\t" ++ string:join(R,",") end,
   case Fields of [] -> []; _ ->
   iolist_to_binary(["        enc: (d) => {\n            let tup = bert.atom('",Class,"');\n    ",
     string:join([ dispatch_enc(Type,Name) || {Name,Type} <- Fields ],";\n    "),
     "\n            return bert.tuple(tup,",StrNames,") } },\n"]) end.

pack({Name,{X,_}}) when X == tuple orelse X == term -> lists:concat(["jsonBert.encode(d.",Name,")"]);
pack({Name,{integer,[]}}) -> lists:concat(["bert.number(d.",Name,")"]);
pack({Name,{list,[]}})    -> lists:concat(["bert.list(d.",Name,")"]);
pack({Name,{atom,[]}})    -> lists:concat(["bert.atom(d.",Name,")"]);
pack({Name,{binary,[]}})  -> lists:concat(["bert.bin(d.",Name,")"]);
pack({Name,{union,[{type,_,nil,[]},{type,_,Type,Args}]}}) -> pack({Name,{Type,Args}});
pack({Name,{union,[{type,_,nil,[]},{atom,_,_}|_]}}) -> lists:concat(["bert.atom(d.",Name,")"]);
pack({Name,Args}) -> io_lib:format("encode(d.~s)",[Name]).

unpack({Name,{X,_}},I) when X == tuple orelse X == term -> lists:concat(["decode(d.v[",I,"].v)"]);
unpack({Name,{union,[{type,_,nil,[]},{type,_,Type,Args}]}},I) -> unpack({Name,{Type,Args}},I);
unpack({Name,{X,[]}},I) when X == binary -> lists:concat(["utf8.dec(d.v[",I,"].v)"]);
unpack({Name,{X,[]}},I) when X == integer orelse X == atom orelse X == list -> lists:concat(["d.v[",I,"].v"]);
unpack({Name,Args},I) -> lists:concat(["decode(d.v[",I,"])"]).

dispatch_dec({union,[{type,_,nil,[]},{type,_,list,Args}]},Name,I) -> dispatch_dec({list,Args},Name,I);
dispatch_dec({list,_},Name,I) -> dec_list(Name,integer_to_list(I));
dispatch_dec(Type,Name,I) ->
    lists:concat(["",Name,": (d && d.v[",I,"]) ? ",unpack({Name,Type},integer_to_list(I))," : undefined"]).

dispatch_enc({union,[{type,_,nil,[]},{type,_,list,Args}]},Name) -> dispatch_enc({list,Args},Name);
dispatch_enc({list,_},Name) -> enc_list(Name);
dispatch_enc(Type,Name) ->
    lists:concat(["        let ", Name," = ('",Name,"' in d && d.",Name,") ? ",pack({Name,Type})," : jsonBert.nil()"]).

enc_list(Name) ->
    lists:flatten(["        let ",Name," = ('",Name,"' in d && d.",Name,") ? ",
        "{t:108, v:d.",Name,".map(jsonBert.encode)} : jsonBert.nil()"]).

dec_list(Name,I) ->
    lists:flatten([Name,": (d && d.v[2] && d.v[2].v) ? d.v[2].v.map(jsonBert.decode) : undefined "]).
