//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SndCustm;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Forms, SyncObjs, SndTypes,
  Ini, MorseKey, Contest, ctypes, portaudio;

type
  TCustomSoundInOut = class;

  TWaitThread = class(TThread)
    private
      Owner: TCustomSoundInOut;
      Msg: TMsg;
      procedure ProcessEvent;
    protected
      procedure Execute; override;
    public
    end;


  TCustomSoundInOut = class(TComponent)
  private
    FDeviceID: UINT;
    FEnabled : boolean;
    procedure SetDeviceID(const Value: UINT);
    procedure SetSamplesPerSec(const Value: LongWord);
    function  GetSamplesPerSec: LongWord;
    procedure SetEnabled(AEnabled: boolean);
    procedure DoSetEnabled(AEnabled: boolean);
    function GetBufCount: LongWord;
    procedure SetBufCount(const Value: LongWord);
  protected
    FThread: TWaitThread;
    rc: UINT;
    DeviceHandle: UINT;
    WaveFmt: UINT;
    Buffers: array of TWaveBuffer;
    FBufsAdded: LongWord;
    FBufsDone: LongWord;
    nSamplesPerSec: LongWord;

     Stream : PPaStream;


    procedure Loaded; override;
    procedure Err(Txt: string);
    function GetThreadID: THandle;

    //override these
    procedure Start; virtual; abstract;
    procedure Stop; virtual; abstract;
    procedure BufferDone(Buf : PWaveBuffer); virtual; abstract;

    property Enabled: boolean read FEnabled write SetEnabled default false;
    property DeviceID: UINT read FDeviceID write SetDeviceID default 0;
    property SamplesPerSec: LongWord read GetSamplesPerSec write SetSamplesPerSec default 48000;
    property BufsAdded: LongWord read FBufsAdded;
    property BufsDone: LongWord read FBufsDone;
    property BufCount: LongWord read GetBufCount write SetBufCount;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  SndObj : TCustomSoundInOut;

const FramesPerBuffer = 512;

 var
 OutputParameters : TPaStreamParameters;




implementation


function PaCallback(
      input: Pointer;
      output: Pointer;
      frameCount: culong;
      timeInfo: PPaStreamCallbackTimeInfo;
      statusFlags: TPaStreamCallbackFlags;
      userData: Pointer ): cint; cdecl;
var
  OutBuffer : pcint16;
  i : culong;
//  LocalDataPointer : PPaUserData;
begin
  OutBuffer := pcint16(output);

  if (SndObj.Buffers[0].used = 1) and (frameCount =  SndObj.Buffers[0].len) then
        for i := 0 to frameCount-1 do
        begin
           OutBuffer[i] := SndObj.Buffers[0].Data[i];
        end
  else
      begin
        for i := 0 to frameCount-1 do
        begin
  	OutBuffer[i] := 0; // Silence
        end;
      end;
    SndObj.Buffers[0].used := 0;
    PaCallback := paContinue;
end;


{ TWaitThread }

//------------------------------------------------------------------------------
//                               TWaitThread
//------------------------------------------------------------------------------

procedure TWaitThread.Execute;
begin
   while not Terminated do
      begin
	 Synchronize(ProcessEvent);
	 Sleep(10);
      end;
end;


procedure TWaitThread.ProcessEvent;
begin
  if (Owner.Buffers[0].used = 0) then
    begin
      Owner.BufferDone(@Owner.Buffers[0]);
    end;
end;

{ TCustomSoundInOut }

//------------------------------------------------------------------------------
//                               system
//------------------------------------------------------------------------------
constructor TCustomSoundInOut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  SetBufCount(DEFAULTBUFCOUNT);
  Writeln('Buffers ', GetBufCount());

  if Pa_Initialize() <> paNoError then
    begin

	Exit;
     end;
   
  //FDeviceID := WAVE_MAPPER;

  //init WaveFmt
  //with WaveFmt do
  //  begin
  //  wf.wFormatTag := WAVE_FORMAT_PCM;
  //  wf.nChannels := 1;             //mono
  //  wf.nBlockAlign := 2;           //SizeOf(SmallInt) * nChannels;
  //  wBitsPerSample := 16;          //SizeOf(SmallInt) * 8;
  //  end;

  //fill nSamplesPerSec, nAvgBytesPerSec in WaveFmt
  SamplesPerSec := 48000;
end;


destructor TCustomSoundInOut.Destroy;
begin
  Enabled := false;
  inherited;
end;


procedure TCustomSoundInOut.Err(Txt: string);
begin
  raise ESoundError.Create(Txt);
end;





//------------------------------------------------------------------------------
//                            enable/disable
//------------------------------------------------------------------------------
//do not enable component at design or load time
procedure TCustomSoundInOut.SetEnabled(AEnabled: boolean);
begin
  if (not (csDesigning in ComponentState)) and
     (not (csLoading in ComponentState)) and
     (AEnabled <> FEnabled)
    then DoSetEnabled(AEnabled);
  FEnabled := AEnabled;
end;


//enable component after all properties have been loaded
procedure TCustomSoundInOut.Loaded;
begin
  inherited Loaded;

  if FEnabled and not (csDesigning in ComponentState) then
    begin
    FEnabled := false;
    SetEnabled(true);
    end;
end;


procedure TCustomSoundInOut.DoSetEnabled(AEnabled: boolean);
var
  PaErr : TPaError;
begin
   if AEnabled then
     begin
        OutputParameters.Device := Pa_GetDefaultOutputDevice;
        OutputParameters.ChannelCount := CInt32(1);
        OutputParameters.SampleFormat := paInt16;
        OutputParameters.SuggestedLatency :=
          (Pa_GetDeviceInfo(OutputParameters.device)^.defaultLowOutputLatency)*1;
        OutputParameters.HostApiSpecificStreamInfo := nil;

        // TODO: Check Error
        PaErr := Pa_OpenStream( Stream, nil, @OutputParameters, nSamplesPerSec,
          FramesPerBuffer, paClipOff, PPaStreamCallback(@PaCallback),
         nil);
        if PaErr <> paNoError then Err('Can not open port audio stream.');
        PaErr := Pa_StartStream( Stream );
        if PaErr <> paNoError then Err('Can not start port audio steam.');

	Ini.BufSize := FramesPerBuffer;//Ini.BufSize;//FramesPerBuffer;  //got^.samples;
	Keyer.BufSize := Ini.BufSize;
	Tst.Filt.SamplesInInput := Ini.BufSize;
	Tst.Filt2.SamplesInInput := Ini.BufSize;

	Writeln('DoSetEnabled true');
	//reset counts
	FBufsAdded := 0;
	FBufsDone := 0;
	//create waiting thread
	FThread := TWaitThread.Create(true);
	FThread.FreeOnTerminate := true;
	FThread.Owner := Self;
	SndObj := Self;
	FThread.Priority := tpTimeCritical;
	//start
	FEnabled := true;
        try Start; except FreeAndNil(FThread); raise; end;
        //device started ok, wait for events
        FThread.Start;
      end
   else
      begin
	 Writeln('DoSetEnabled false');
	 FThread.Terminate;
	 Stop;
   end;
end;


//------------------------------------------------------------------------------
//                              get/set
//------------------------------------------------------------------------------

procedure TCustomSoundInOut.SetSamplesPerSec(const Value: LongWord);
begin
   Enabled := false;

   Writeln('SetSamplesPerSec ', Value);

   nSamplesPerSec := Value;   
end;


function TCustomSoundInOut.GetSamplesPerSec: LongWord;
begin
  Result := nSamplesPerSec;
end;



procedure TCustomSoundInOut.SetDeviceID(const Value: UINT);
begin
  Enabled := false;
  FDeviceID := Value;
end;



function TCustomSoundInOut.GetThreadID: THandle;
begin
   Result := THandle(FThread.ThreadID);
end;


function TCustomSoundInOut.GetBufCount: LongWord;
begin
  Result := Length(Buffers);
end;

procedure TCustomSoundInOut.SetBufCount(const Value: LongWord);
begin
  if Enabled then
    raise Exception.Create('Cannot change the number of buffers for an open audio device');
  SetLength(Buffers, Value);
end;







end.

