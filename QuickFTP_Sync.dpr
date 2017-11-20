program QuickFTP_Sync;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.DateUtils,
  System.Classes,
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Log,
  uCore,
  uModel,
  uConfig,
  uGlobal;

const
  Version = '1.0';
  CONSMailSubject = 'QuickFTPSync Resume';

{ TEventHandlers }

begin
  { TODO -oUser -cConsole Main : Insert code here }
  try
    try
      log := TQuickLog.Create;
      log.SetLog('QuickFtpSync.log', True, 20);
      AppArguments := New(PAPPArguments);
      if TArgCore.ProcessArguments(AppArguments) then
      begin
        TConfigCore.ValidateConfig;
        TAppCore.Process;
      end;
    except
      on e : Exception do Cout(e.ToString, TEventType.etWarning);
    end;
  finally
    Dispose(AppArguments);
  end;
end.
