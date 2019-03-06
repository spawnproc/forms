-module(forms_index).
-copyright('Maxim Sokhatsky').
-compile(export_all).
-include_lib("n2o/include/n2o.hrl").
-include_lib("nitro/include/nitro.hrl").

main() -> [].
body() -> [].

event(init) ->

    % ensure blank page
    nitro:clear(stand),

    [ begin

      Module = nitro:to_atom(filename:basename(F,".erl")),
      FORM   = Module:new([],Module:id()),
      NITRO  = forms:new(FORM, []),
      HTML5  = nitro:render(lists:flatten(nitro:render(NITRO))),
      Bin    = nitro:to_binary(HTML5),


      % Module name as a title
      nitro:insert_bottom(stand, lists:flatten(nitro:to_list(nitro:render(#h3{body=Module})))),

      % Display form information
      nitro:insert_bottom(stand, #p{body = [nitro:f("Size: ~p/HTML ~p/BERT",
                                   [size(Bin),size(term_to_binary(FORM,[compressed]))]), "<br>",
                                    nitro:f("Type: ~p", [element(1,FORM)])]}),

      % Form itself as HTML5 piece of code
      nitro:insert_bottom(stand, lists:flatten(nitro:to_list(Bin))),

      % Display Form Instance in BERT
      nitro:insert_bottom(stand, lists:flatten(nitro:jse(nitro:to_list("<figure><code>\n  "
                                                           ++ forms:translate(FORM) ++
                                                                 "\n\n</code></figure>"))))

      end || F <- lists:sort(mad_repl:wildcards(["src/forms/**/*.erl"])) ],
    io:format("HELO: OK~n");

event(Event) ->   n2o:info(?MODULE,"unknown: ~p",    [Event]).