program QuickFTP_Sync;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.DateUtils,
  System.Classes,
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Threads,
  Quick.Logger,
  Quick.Logger.Provider.Files,
  uCore,
  uModel,
  uConfig,
  uGlobal;

const
  Version = '1.0';
  CONSMailSubject = 'QuickFTPSync Resume';

var
  finished : Boolean = False;

{ TEventHandlers }
begin
  { TODO -oUser -cConsole Main : Insert code here }
  try
    try
      with GlobalLogFileProvider do
      begin
        AutoFileNameByProcess := True;
        DailyRotate := True;
        CompressRotatedFiles := True;
        Enabled := True;
      end;
      Logger.Providers.Add(GlobalLogFileProvider);
      Logger.Info('Program start.');
      AppArguments := New(PAPPArguments);
      if TArgCore.ProcessArguments(AppArguments) then
      begin
        TConfigCore.ValidateConfig;
        TAnonymousThread.Execute(
        procedure
        begin
          repeat
            TAppCore.Updateconsole;
            Sleep(260);
          until (finished);
        end
        ).Start;
        TAppCore.Process;
        finished := True
      end;
    except
      on e : Exception do Cout(e.ToString, TLogEventType.etError);
    end;
  finally
    Dispose(AppArguments);
  end;
end.
