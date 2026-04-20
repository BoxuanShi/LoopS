ClearAll[ToStringHold]
ToStringHold[expr_] := StringTake[ToString[Hold[expr]], {6, -2}]
Attributes[ToStringHold] = {HoldAll};


ClearAll[ToStringInput]
ToStringInput[expr_] := ToString[expr, InputForm]


ClearAll[ToStringNoContext]
ToStringNoContext::unknowform = "Unknow form `1` encountered.";
ToStringNoContext[expr_, opt : OptionsPattern[{ToString}]] := ToStringNoContext[expr, opt, OutputForm]
ToStringNoContext[expr_, form : OutputForm | InputForm | StandardForm | TextForm, opt : OptionsPattern[{ToString}]] := ToString[expr, form, opt] // StringDelete[#, RegularExpression["([A-Za-z][A-Za-z0-9]*`)+"]] &;
ToStringNoContext[expr_, form : CForm, opt : OptionsPattern[{ToString}]] := ToString[expr, form, opt] // StringDelete[#, RegularExpression["([A-Za-z][A-Za-z0-9]*_)+"]] &;
ToStringNoContext[expr_, form_, opt : OptionsPattern[{ToString}]] := (Message[ToStringNoContext::unknowform, form]; ToString[expr, form, opt]);