// Version 0.1.1 (30/9/201)
//   -- fix for Altium Designer Release 10
//
// Version 0.1 (12/1/2009)
//   -- initial implemenation - Ben Benardos


Var
     TRACK_WIDTH : TCoord;
     TRACK_LAYER : TLayer;
     PATTERN     : TList;
     PATTERN_UNIT: TCoord;

Function SetPattern_Dash(Scale : TCoord);
Begin
     PATTERN.Clear;
     PATTERN.Add(1);
     PATTERN.Add(1);

     PATTERN_UNIT := Scale;
End;

Function SetPattern_DashDot(Scale : TCoord);
Begin
     PATTERN.Clear;
     PATTERN.Add(10);
     PATTERN.Add(5);
     PATTERN.Add(1);
     PATTERN.Add(5);

     PATTERN_UNIT := Scale;
End;

Function SetConstants(Dymmy : Integer);
Begin
     TRACK_WIDTH :=  MilsToCoord(1);
     PATTERN := TList.Create;

     //SetPattern_Dash(MilsToCoord(5));
     SetPattern_DashDot(MilsToCoord(1));
End;

Var
   Board : IObject;
   IsSpace : Boolean;
   I : Integer;
   UnionIndex : Integer;

Function Length(x, y : Extended) : Extended;
Var
   d : Extended;
Begin
     // workaround for what seems to be wrapping
     x := x / k1Mil;
     y := y / k1Mil;
     d := x * x + y * y;
     Result := Sqrt(d) * k1Mil;
End;

Procedure AddTrack(P1X, P1Y, P2X, P2Y : TCoord);
Var
   Track : IObject;
Begin
     Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
     Track.X1 := P1X;
     Track.Y1 := P1Y;
     Track.X2 := P2X;
     Track.Y2 := P2Y;
     Track.Layer := TRACK_LAYER;
     Track.Width := TRACK_WIDTH;
     Track.UnionIndex := UnionIndex;
     Board.AddPCBObject(Track)
End;

Procedure Interpolate(P1X, P1Y, P2X, P2Y : TCoord; t : Double, Var X, Y : TCoord);
Var
    dx, dy, l, ux, uy : Double;
Begin
    dx := p2X - p1X;
    dy := p2Y - p1Y;
    l := Length(dx, dy);
    ux := dx / l;
    uy := dy / l;

    x := p1X + ux * t;
    y := p1y + uy * t;
End;

Procedure GetDashLength(I : Integer; Var DashLength : Extended);
Begin
    I := I Mod PATTERN.Count;
    DashLength := PATTERN[I] * PATTERN_UNIT;
End;

Procedure AddDashes(P1X, P1Y, P2X, P2Y : TCoord; Var tRemainder : Extended);
Var
    tMax, tStart, tEnd : Extended;
    tChange : Extended;
    StartPointX, StartPointY, EndPointX, EndPointY : TCoord;
    Go : Boolean;
Begin
    tMax := Length(p1x - p2x, p1y - p2y);

    tStart := 0;
    Go := True;
    While Go Do
    Begin
         if tRemainder > 0 Then
         Begin
              tChange := tRemainder;
              tRemainder := 0;
         End
         Else
         Begin
              GetDashLength(I, tChange);
         End;

         tEnd := tStart + tChange;

        if tEnd > tMax then
        Begin
             tRemainder := tEnd - tMax;
             tEnd := tMax;
             Go := False;
        end;

        if Not IsSpace then
        Begin
            Interpolate(P1X, P1Y, P2X, P2Y, tStart, StartPointX, StartPointY);
            Interpolate(P1X, P1Y, P2X, P2Y, tEnd, EndPointX, EndPointY);
            AddTrack(StartPointX, StartPointY, EndPointX, EndPointY);
        End;

        tStart := tEnd;

        If Go Then
        Begin
           IsSpace := Not IsSpace;
           Inc(I);
        End;
    End;
End;

Function  DoesUnionIndexExits(Index : Integer) : Boolean;
Var
   Iterator, Primitive : IObject;
Begin
    Result := False;

    Iterator        := Board.BoardIterator_Create;
    Iterator.SetState_FilterAll;

    Primitive := Iterator.FirstPCBObject;
    While (Primitive <> Nil) Do
    Begin
        If Primitive.UnionIndex = Index Then
        Begin
           Result := True;
           Break;
        End;

        Primitive := Iterator.NextPCBObject;
    End;
    Board.BoardIterator_Destroy(Iterator);
End;

Procedure SetupUnionIndex(Dummy : Integer);
Begin
     Randomize;
     Repeat
       UnionIndex := Random(2147483647);
     Until Not DoesUnionIndexExits(UnionIndex);
End;

procedure Main;
Var
   CoordX : TList;
   CoordY : TList;
   P1X, P1Y, P2X, P2Y : TCoordPoint;
   tRemainder : Extended;
Begin
     SetConstants(1);

     Board := PCBServer.GetCurrentPCBBoard;

     If Board = Nil Then
     Begin
          ShowError('Current document is not a PCB');
          Exit;
     End;

     TRACK_LAYER := Board.CurrentLayer;

     tRemainder := 0;
     I := 0;
     IsSpace := False;

     SetupUnionIndex(1);

     If Not Board.ChooseLocation(P1X, P1Y, '') Then
        Exit;

     Pcbserver.PreProcess;
     While Board.ChooseLocation(P2X, P2Y, '') Do
     Begin
          AddDashes(P1X, P1Y, P2X, P2Y, tRemainder);
          Board.GraphicalView_ZoomRedraw;
          P1X := P2X;
          P1Y := P2Y;
     End;
     Pcbserver.PostProcess
End;
