program MorseRunner;

//{$MODE Delphi}
{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Forms, Interfaces,
  Main in 'Main.pas' {MainForm},
  Contest in 'Contest.pas',
  RndFunc in 'RndFunc.pas',
  Ini in 'Ini.pas',
  Station in 'Station.pas',
  MorseKey in 'VCL\MorseKey.pas',
  StnColl in 'StnColl.pas',
  DxStn in 'DxStn.pas',
  MyStn in 'MyStn.pas',
  CallLst in 'CallLst.pas',
  QrmStn in 'QrmStn.pas',
  Log in 'Log.pas',
  Qsb in 'Qsb.pas',
  DxOper in 'DxOper.pas',
  QrnStn in 'QrnStn.pas',
  ScoreDlg in 'ScoreDlg.pas' {ScoreDialog},
  BaseComp in 'VCL\BaseComp.pas',
  Crc32 in 'VCL\Crc32.pas',
  SndCustm in 'VCL\SndCustm.pas',
  SndTypes in 'VCL\SndTypes.pas',
  SndOut in 'VCL\SndOut.pas',
  MorseTbl in 'VCL\MorseTbl.pas',
  QuickAvg in 'VCL\QuickAvg.pas',
  MovAvg in 'VCL\MovAvg.pas',
  Mixers in 'VCL\Mixers.pas',
  VolumCtl in 'VCL\VolumCtl.pas',
  VolmSldr in 'VCL\VolmSldr.pas',
  WavFile in 'VCL\WavFile.pas';

{$R *.res}

begin

  Application.Scaled:=True;
  Application.Initialize;
  Application.Title := 'Morse Runner';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TScoreDialog, ScoreDialog);
  Application.Run;
end.

