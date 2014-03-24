%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2014 GoPivotal, Inc.  All rights reserved.
%%

-module(truncate).

-define(ELLIPSIS_LENGTH, 3).

-export([log_event/3]).
%% exported for testing
-export([test/0, term/3]).

log_event({Type, GL, {Pid, Format, Args}}, Size, Decr)
  when Type =:= error orelse
       Type =:= info_msg orelse
       Type =:= warning_msg ->
    {Type, GL, {Pid, Format, [term(T, Size, Decr) || T <- Args]}};
log_event({Type, GL, {Pid, ReportType, Report}}, Size, Decr)
  when Type =:= error_report orelse
       Type =:= info_report orelse
       Type =:= warning_report ->
    Report2 = case ReportType of
                  crash_report -> [[{K, term(V, Size, Decr)} || {K, V} <- R] ||
                                      R <- Report];
                  _            -> [{K, term(V, Size, Decr)} || {K, V} <- Report]
              end,
    {Type, GL, {Pid, ReportType, Report2}};
log_event(Event, _Size, _Decr) ->
    Event.

term(_, N, _) when N =< 0 ->
    '...';
term(Bin, N, _D) when is_binary(Bin) andalso size(Bin) > N - ?ELLIPSIS_LENGTH ->
    Suffix = without_ellipsis(N),
    <<Head:Suffix/binary, _/binary>> = Bin,
    <<Head/binary, <<"...">>/binary>>;
term(L, N, D) when is_list(L) ->
    IsPrintable = io_lib:printable_list(L),
    case IsPrintable of
        true  -> case length(L) > without_ellipsis(N) of
                     true  -> string:left(L, without_ellipsis(N)) ++ "...";
                     false -> L
                 end;
        false -> shrink_list(L, N, D)
    end;
term(T, N, D) when is_tuple(T) ->
    shrink_tuple(T, N, D);
term(T, _, _) ->
    T.

without_ellipsis(N) -> erlang:max(N - ?ELLIPSIS_LENGTH, 0).

shrink_list(_, 0, _) ->
    ['...'];
shrink_list([], _N, _D) ->
    [];
shrink_list([H|T], N, D) ->
    [term(H, N - D, D) | case is_list(T) of
                             true  -> shrink_list(T, N - 1, D);
                             false -> term(T, N - 1, D)
                         end].

shrink_tuple(T, N, D) ->
    shrink_tuple(T, N, D, erlang:min(tuple_size(T), N)).

shrink_tuple(_T, _N, _D, 0) ->
    {};
shrink_tuple(T, N, D, Ix) ->
    erlang:append_element(shrink_tuple(T, N, D, Ix - 1),
                          term(element(Ix, T), N - D, D)).

%%----------------------------------------------------------------------------

test() ->
    test_short_examples_exactly(),
    test_large_examples_for_size(),
    ok.

test_short_examples_exactly() ->
    F = fun (Term, Exp) -> Exp = term(Term, 10, 5) end,
    F([], []),
    F("h", "h"),
    F("hello world", "hello w..."),
    F([a|b], [a|b]),
    F([<<"hello world">>], [<<"he...">>]),
    F({{{{a}}},{b},c,d,e,f,g,h,i,j,k}, {{'...'},{'...'},c,d,e,f,g,h,i,j}),
    P = spawn(fun() -> receive die -> ok end end),
    F([0, 0.0, <<1:1>>, F, P], [0, 0.0, <<1:1>>, F, P]),
    P ! die,
    ok.

test_large_examples_for_size() ->
    %% TODO
    ok.
