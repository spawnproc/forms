-module(form_backend).
-compile(export_all).
-include_lib("nitro/include/calendar.hrl").
-include_lib("nitro/include/comboLookup.hrl").
-include_lib("nitro/include/comboLookupVec.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("form/include/formReg.hrl").
-include_lib("form/include/step_wizard.hrl").
-include_lib("form/include/meta.hrl").

sources(Object,Options) ->
   M = lists:map(fun(X) -> list_to_atom(form:atom([X,form:type(Object),form:kind(Options)])) end, element(5,kvs:table(form:type(Object)))),
%   io:format("sources: ~p~n",[M]),
   M.

type(O) -> element(1,O).

kind(Options) ->
   case lists:filter(fun ({_Y,Z}) -> Z end,
       [ {X,proplists:get_value(X,Options,false)} || X <- [create,view,search,edit]]) of
        [] -> none;
        [{K,true}|_] -> K end.

pos(Object,X) ->
   Tab = element(1,Object),
   Fields = element(5,kvs:table(Tab)),
   P = string:rstr([Tab|Fields],[X#field.id]),
   % io:format("pos: ~p~n",[{P,Object,X}]),
   P.
extract(Object,X) -> extract(Object,X,false).
extract({_, Value}, X, true) -> extract_ref(Value, X#field.module);
extract({_, Value}, _X, false) -> Value;
extract(Object, X, false) ->
   Pos = form:pos(Object,X),
   Value = element(Pos, Object),
   % io:format("extract: ~p~n",[{Pos, Value, Object}]),
   Value;
extract(Object, X, true) ->
   Ref = extract(Object, X, false),
   Value = extract_ref(Ref, X#field.module),
   % io:format("extract ref: ~p~n",[{Value, Ref, Object, X}]),
   Value
.
extract_ref(Ref, Module) when is_tuple(Ref) ->
   case has_function(Module, view_value) of
      true -> Module:view_value(Ref);
      false -> element(3, Ref)
   end;
extract_ref(Ref, _Module) -> Ref.
has_function([], _F) -> false;
has_function(M, F) ->
   Functions = apply(M, module_info, [exports]),
   IsF = proplists:get_value(F, Functions, -1),
   IsF /= -1.

evoke(Object,X,Value) ->
   setelement(form:pos(Object,X),Object,Value).

translate_error(A,B) -> io_lib:format("~p",[{A,B}]).
translate(A,B)       -> io_lib:format("~p",[{A,B}]).
translate(A)         -> io_lib:format("~p",[A]).

dispatch(Object, Options) ->
   Name = proplists:get_value(name,Options,false),
   % Row = proplists:get_value(row,Options,false),
   Registry = application:get_env(form,registry,[]),
   #formReg{vertical = V, horizontal = H} = lists:keyfind(element(1,Object),2,Registry:registry()),
   Module = case proplists:get_value(row,Options,false) of true -> H; false -> V end,
   form:new(Module:new(nitro:compact(Name),Object,Options),Object,Options).

new(Document = #document{},Object,Opt) ->
%   io:format("new options: ~p~n",[Opt]),
    Name = Document#document.name,
    #panel{
        id=form:atom([form,Name]), class=form,
        body= [ BuildBlock(Document, Object, Opt)
             || BuildBlock <- [fun steps/3,fun caption/3,fun fields/3,fun buttons/3]]};

new(Document,_Object,_Opt) -> Document. % pass HTML5 as NITRO records

new(A,B) -> new(A,B,[]).

steps(Document, _Object, _Opt) ->
    StepWizard = Document#document.steps,
    case StepWizard of
        #step_wizard{} ->
            #panel{class=steps, body= ["<b>", nitro:f(translate(step_wizard),
                [StepWizard#step_wizard.current_step,StepWizard#step_wizard.steps]), "</b>" ] };
        _ -> []
    end.

caption(Document, _Object, _Opt) ->
    SectionList  = Document#document.sections,
    #panel{class=caption,body=
         [begin
            [#h4{ class=Section#sec.nameClass, body=Section#sec.name},
             #panel{ class=Section#sec.descClass, body = Section#sec.desc}]
          end || Section <- SectionList]}.

fields(Document, Object, Opt) ->
   %  Name       = Document#document.name,
    Fields     = Document#document.fields,
    lists:foldr(fun (X,Acc) -> form:fieldType(X,Acc,Object,Opt) end,[],Fields).

field(Field) -> 
   Id = element(2, Field),
   [_Name, Doc, Type] = string:tokens(Id, "_"),
   field(Field, {nitro_conv:to_atom(Doc)}, {nitro_conv:to_atom(Type)}).

field(Field, Object, Opt) -> 
   form:fieldType(Field, [], Object, Opt).


buttons(Document, Object, _Opt) ->
   %  Name    = Document#document.name,
    Buttons  = Document#document.buttons,
    #panel{ id = forpreload, class = buttons,
            body= lists:foldr(fun(#but{}=But,Acc) ->
                [ #link { id=form:atom([But#but.id,form:type(Object),form:kind(_Opt)]), class=But#but.class,
                          validate=But#but.validation,
                          postback=But#but.postback,
                          body=But#but.title, onclick=But#but.onclick,
                          href=But#but.href, target=But#but.target,
                          source=But#but.sources}|Acc] end, [], Buttons)}.

% GENERIC MATCH

fieldType(#field{type=empty}=X,Acc,Object,Opt) ->
    [#panel{class=box, style="display:none;",id=form:atom([X#field.id,form:type(Object),form:kind(Opt)])}|Acc];

fieldType(#field{type=dynamic}=X,Acc,_Object,_Opt) ->
    [X#field.raw|Acc];

fieldType(#field{type=comment}=X,Acc,Object,Opt) ->
    [#panel { id=form:atom([commentBlock,form:type(Object),form:kind(Opt)]), class=box, body=[
         case X#field.tooltips of
              false -> [];
              true -> [ #panel { class=label, body="&nbsp;" },
                        #panel { class=field, body="&nbsp;" },
                        #panel { class=tool, body=[
                         #link { id=form:atom([commentlink,X#field.id]),
                                 class=tooltips,
                                 onclick=nitro:f("showComment(this);"),
                                 body=[#image{src=[]} ]} ]}] end,
                        #panel { class=comment,
                                 id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
                                 body=[X#field.desc],
                                 style= case X#field.tooltips of
                                             false -> "";
                                             true  -> "display:none;" end} ]}|Acc];

fieldType(#field{type=card}=X,Acc,Object,Opt) ->
   [#panel { id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]), class=[box,pad0], body=[
             #panel { class=label, body = X#field.title},
             #panel { class=field, style="width:66.63%", body=
                       #panel { id=form:atom([X#field.id,1]), body=[
                       #panel { class=field,style="width:90%;", body =
                      #select { id=form:atom([X#field.id,2]), disabled=true,
                                validation=form:val(Opt,"Validation.card(e)"),
                                body= #option{selected=true, body= form:translate(loading)}}},
                       #panel { class=tool, body= [#image{src=[]}]} ]}} ]}|Acc];

fieldType(#field{type=bool}=X,Acc,Object,Opt) ->
  Val = form:extract(Object,X),
  Options = [ #opt{name = <<"true">>, title =  <<"Так"/utf8>>, checked = Val == true},
              #opt{name = <<"false">>, title = <<"Ні"/utf8>>, checked = Val == false},
              #opt{name = <<"">>, title = <<"Не вибрано"/utf8>>, checked = not is_boolean(Val)}],
  form:fieldType(X#field{type=select, options=Options},Acc,Object,Opt);

fieldType(#field{}=X,Acc,Object,Opt) ->
   Panel = case X#field.id of [] -> #panel{};
                                 _ -> #panel{id=form:atom([wrap,X#field.id,form:type(Object),form:kind(Opt)])} end,
   Tooltips =
   [ case Tx of
          {N} -> #panel{ id=form:atom([tooltip,N]), body=[]};
          _ -> #link { class=tooltips,
                       tabindex="-1",
                       onmouseover="setHeight(this);",
                       body=[ #image { src= "app/img/question.png" },
                              #span  { body=Tx } ]} end || Tx <- lists:reverse(X#field.tooltips) ],

   Options = [ case {X#field.type, O#opt.noRadioButton} of

          {_,true}     -> #label{ id=form:atom([label,O#opt.name]),
                                  body=[]};

          % SELECT/OPTION

          {select,_}  -> #option{ value = O#opt.name,
                                  body = O#opt.title,
                                  selected = O#opt.checked};

          % COMBO/RADIO

          {combo,_}    -> #panel{ body=
                          #label{ body=
                          #radio{ name=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
                                  id=form:atom([X#field.id,form:type(Object),O#opt.name]),
                                  body = O#opt.title,
                                  checked=O#opt.checked,
                                  disabled=O#opt.disabled,
                                  value=O#opt.name,
                                  postback = { X#field.id,
                                               type(Object),
                                               O#opt.name}}}};

          % CHECKBOX

          {check,_}  ->  #checkbox{id=form:atom([O#opt.name,form:type(Object),form:kind(Opt)]),
                                   source=[form:atom([O#opt.name])],
                                   body = O#opt.title,
                                   disabled=O#opt.disabled,
                                   checked=O#opt.checked,
                                   postback={O#opt.name}}

            end || O <- X#field.options ],


%   io:format("O: ~p~n",[{X,Object}]),

   [ Panel#panel { class=X#field.boxClass, body=[
          #panel { class=X#field.labelClass, body = X#field.title},
          #panel { class=X#field.fieldClass, body = form:fieldType(X#field.type,X,Options,Object,Opt)},
          #panel { class=tool, body= case Tooltips of
                   [] -> [];
                    _ -> Dom = case length(Tooltips) of
                              1 -> #br{};
                              _ -> #panel{style="height:10px;"} end,
                         tl(lists:flatten(lists:zipwith(fun(A2,B2) -> [A2,B2] end,
                            lists:duplicate(length(Tooltips),Dom),Tooltips)))
                  end} ]}|Acc].

% SECOND LEVEL MATCH

fieldType(text,X,_Options,Object,Opt) ->
    #panel{id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]), body=X#field.desc};

fieldType(integer,X,_Options,Object,_Opt) ->
    nitro:f(X#field.format,
           [ case X#field.postfun of
                  [] -> pos(Object,X);
                  PostFun -> PostFun(pos(Object,X)) end] );

fieldType(money,X,_Options,Object,Opt) ->
 [ #input{ id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]), pattern="[0-9]*",
           validation=form:val(Opt,nitro:f("Validation.money(e, ~w, ~w, '~s')",
                                      [X#field.min,X#field.max, form:translate({?MODULE, error})])),
           onkeyup="beautiful_numbers(event);",
           value=nitro:to_list(form:extract(Object,X)) },
           #panel{ class=pt10,body= [ form:translate({?MODULE, warning}),
                                      nitro:to_binary(X#field.min), " ", X#field.curr ] } ];

fieldType(pay,X,_Options,Object,Opt) ->
   #panel{body=[#input{ id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]), pattern="[0-9]*",
                        validation=form:val(Opt,X#field.validation),
                        onkeypress=nitro:f("return fieldsFilter(event, ~w, '~w');",
                           [X#field.length,X#field.type]),
                        onkeyup="beautiful_numbers(event);",
                        value=nitro:to_list(form:extract(Object,X)) }, <<" ">>,
                 #span{ body=X#field.curr}]};

fieldType(ComboCheck,_X,Options,_Object,_Opt) when ComboCheck == combo orelse ComboCheck == check ->
   Dom = case length(Options) of 1 -> #br{}; _ -> #panel{} end,
   tl(lists:flatten(lists:zipwith(fun(A,B) -> [A,B] end,
      lists:duplicate(length(Options),Dom),Options)));

fieldType(select,X,Options,Object,Opt) ->
   #select{ id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]), postback=X#field.postback,
     disabled = X#field.disabled,
     body=Options};

fieldType(string,X,_Options,Object,Opt) ->
   #input{ class=column,
           id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
           disabled = X#field.disabled,
           validation=form:val(Opt,nitro:f("Validation.length(e, ~w, ~w)",[X#field.min,X#field.max])),
           value=form:extract(Object,X)};

fieldType(phone,X,_Options,Object,Opt) ->
   #input{ id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
           class=phone,
           pattern="[0-9]*",
           onkeypress=nitro:f("return fieldsFilter(event, ~w, '~w');",[X#field.length,X#field.type]),
           validation=form:val(Opt,nitro:f("Validation.phone(e, ~w, ~w)",[X#field.min,X#field.max])),
           value=form:extract(Object,X)};

fieldType(auth,X,_Options,Object,Opt) ->
 [ #input{ id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
           class=phone,
           type=password,
           onkeypress="return removeAllErrorsFromInput(this);",
           onkeyup="nextByEnter(event);",
           validation=form:val(Opt,nitro:f("Validation.length(e, ~w, ~w)",[X#field.min,X#field.max])),
           placeholder= form:translate({auth, holder}) },
    #span{ class=auth_link,
           body = [ #link{ href= form:translate({auth, lost_pass_link}),
                           target="_blank", postback=undefined,
                           body= form:translate({auth, lost_pass}) }, #br{},
                    #link{ href= form:translate({auth, change_login_link}),
                           target="_blank", postback=undefined,
                           body= form:translate({auth, change_login}) }]} ];

fieldType(otp,X,_Options,Object,Opt) ->
   #input{ class=[phone,pass],
           type=password,
           id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
           placeholder="(XXXX)",
           pattern="[0-9]*",
           validation=form:val(Opt,"Validation.nums(e, 4, 4, \"otp\")")
         };

fieldType(comboLookup,X,_Options,Object,Opt) ->
  #comboLookup{id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
               disabled = X#field.disabled,
               validation=form:val(Opt,nitro:f("Validation.comboLookup(e, ~w, ~w)",[X#field.min,X#field.max])),
               feed = X#field.bind,
               value = form:extract(Object,X,true),
               bind = case form_backend:has_function(X#field.module, view_value) of
                           true -> form:extract(Object,X,false);
                           false -> [] end,
               delegate = X#field.module,
               reader=[],
               chunk=20};

fieldType(comboLookupVec,X,Options,Object,Opt) ->
  Id = form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
  Delegate = X#field.module,
  Input = #comboLookup{
            id = form:atom([Id, "input"]),
            feed = X#field.bind,
            delegate = Delegate,
            reader = [],
            style = "padding-bottom: 10px; margin: 0; background-color: inherit;",
            chunk = 20},
  Disabled = X#field.disabled,
  RawValues = form:extract(Object,X),
  Values = case form_backend:has_function(Delegate, view_value) of
              true -> {view_value_pairs, [ {Delegate:view_value(V), V} || V <- RawValues]};
              false -> RawValues end,
  Min = X#field.min,
  Max = X#field.max,
  Validation = if not X#field.required -> [];
                  true -> form:val(Opt,nitro:f("Validation.length(e, ~w, ~w)",[Min, Max])) end,
  #comboLookupVec{id = Id,
             input = Input,
             disabled = Disabled,
             validation = Validation,
             values = Values};

fieldType(file,_X,_Options,_Object,_Opt) -> [];

fieldType(calendar,X,_Options,Object,Opt) ->
   #panel{class=[field],
          body=[#calendar{value = form:extract(Object,X),
                           id=form:atom([X#field.id,form:type(Object),form:kind(Opt)]),
                           disabled = X#field.disabled,
                           onkeypress="return removeAllErrorsFromInput(this);",
                           validation=form:val(Opt,"Validation.calendar(e)"),
                           disableDayFn="disableDays4Charge",
                           class = ['input-date'],
                           minDate=X#field.min,
                           maxDate = X#field.max,
                           lang=ua}]}.

val(Options,Validation) ->
   case proplists:get_value(search,Options,false) of
        true -> [];
        false -> Validation end.
