unit uCore;

interface

uses
  System.Math,
  uModel,
  uConfig,
  uGlobal,
  Quick.Logger,
  Quick.Console,
  Quick.Threads,
  Quick.Commons,
  Nullpobug.ArgumentParser,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.DateUtils,
  System.Types,
  IdComponent,
  IdFTP,
  IdFTPList,
  IdFTPCommon,
  IdFTPListTypes,
  QuickSMTP;

type
  TFTPDirectoryNotfoundException = class(Exception); 
  TFTPDirectoryCantCreateException = class(Exception);
  TFTPDirectoryCantDown = class(Exception);

  TFTPOnConnected = procedure(Sender: TObject) of object;
  TFTPOnDisconnected = procedure(Sender: TObject) of object;
  TFTPOnStatus = procedure(Sender: TObject; Astatus: TIdStatus; const AText: string)
      of object;
  TFTPOnWork = procedure(Sender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64)
      of object;
  TFTPOnWorkStart = procedure(Sender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: Int64) of object;
  TFTPWorkEnd = procedure(Sender: TObject; AWorkMode: TWorkMode) of object;

  TIODirectoryFound = procedure(Sender: TObject; const Path: string) of object;
  TIODirectoryCancel = procedure(Sender : TObject) of object;
  TIOFileFound = procedure(Sender : TObject; const FilePath : string) of object;
  TIODirectoryList = procedure of object;
  TIOProcessEnd = procedure(Sender : TObject) of object;

  TIODirectoryEND = procedure(Sender : TObject) of object;

  TConfigCore = class
  public
    class procedure LoadConfig(const ConfigPath: string);
    class procedure NewConfig(const ConfigPath: string);
    class procedure ValidateConfig;
  end;

  TConsole = class
    class procedure SuccessOperation(const Msg : string);
    class procedure LocalOperation(const Msg : string);
    class procedure TargetOperation(const Msg : string);
    class procedure Errors(const Msg : string);
    class procedure Info(Const Msg : string);
    class procedure ProcessInfo(const Msg : string);
  end;

  TFTPHandler = class
    private
      fftpclient : TIdFTP;
      fisconnected : Boolean;
      fcurrentfile : string;
      fftphandlerexceed : Boolean;
      fioretries : Integer;
      fcurrentdirectory : string;
      fislogged : Boolean;
      FEndWork: Boolean;
      procedure SetEndWork(const Value: Boolean);
    public
      property EndWork : Boolean read FEndWork write SetEndWork;
      constructor Create;
      procedure Init;
      procedure CheckConnection;
      procedure UploadFile(const Path : string);
      procedure CreateFolder(const Folder : string);
      procedure ChangeFolder(const Folder : string);
      procedure DownDirectory;
      procedure OnFTPConnected(Sender: TObject);
      procedure OnFTPDisconnected(Sender : TObject);
      procedure OnFTPWork(Sender: TObject; Astatus: TIdStatus; const AText: string);
      procedure OnFTPWorkStart(Sender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
      procedure OnFTPFolderFound(Sender : TObject; const Folder : string);
      procedure OnFTPFolderChanged(Sender : TObject; const Folder : string);
      procedure OnFileUploaded(Sender : TObject; const Filename : string);
      procedure OnFileNotUploaded(Sender : TObject; const Filename : string);
      procedure OnFTPFolderCantCreate(Sender : TObject; const Folder : string);
  end;

  TIOCore = class
  public
    class function FileLen(const Path: string): Integer;
    class procedure SourceCheck;
    class procedure OnDirectoryFound(Sender: TObject; const Path: string);
    class procedure OnDirectoryCancel(Sender : TObject);
    class procedure OnFileFound(Sender : TObject; const FilePath : string);
    class procedure OnDirectoryEnd(Sender : TObject);
    class procedure OnProcessEnd(Sender : TObject);
  end;

  TIOHandler = class
  private
    fstarttime : TDateTime;
    fendtime : TDateTime;
    fftphandler : TFTPHandler;
    fonprocessend : TIOProcessEnd;
    fondirecotriesfetch: TIODirectoryFound;
    foncancel : TIODirectoryCancel;
    fondirectoryend : TIODirectoryEND;
    fonfilefound : TIOFileFound;
    fcancel : Boolean;
    flocalpath : string;
    ftotaldirectories : Integer;
    fprocesseddirectories : Integer;
    fprocessedfiles : Integer;
    ftotalfiles : Integer;
    fdeletedfiles : Integer;
    fuploadedfiles : Integer;
    fnumtasks : Integer;
    fend : Boolean;
    fnumofrootdirectories : Integer;
    ftasks : TBackgroundTasks;    
    fcurrentdirectory : string;    
    procedure SetCurrentDirectory(const Value: string);
  public
    property OnDirectoriesFetch: TIODirectoryFound
      read fondirecotriesfetch write fondirecotriesfetch;
    property OnDirectoriesCancel : TIODirectoryCancel read foncancel write foncancel;
    property OnFileFound : TIOFileFound read fonfilefound write fonfilefound;
    property OnDirectoryEND : TIODirectoryEND read fondirectoryend write fondirectoryend;
    property OnProcessEnd : TIOProcessEnd read fonprocessend write fonprocessend;
    property Cancel : Boolean read fcancel write fcancel;
    property CurrentDirectory : string read FCurrentDirectory write SetCurrentDirectory;
    procedure GetDirectories(const Path : string; Recurse : Boolean; IsRootPath : Boolean);
    procedure GetFiles(const Path : string);
    procedure PrintStatus;
    procedure EndJob;
    constructor Create(FTPHandler : TFTPHandler);
  end;

  TAppCore = class
  private
    class procedure PrintHelp;
    class procedure IniThreadPool;
  public
    class procedure Process;
    class procedure UpdateConsole;
  end;

  TArgCore = class
  public
    class function ProcessArguments(Args: PAPPArguments): Boolean;
  end;

implementation

const
  HELP = 'Quick FTP Uploader ' + #13#10 + '--help shows this help' + #13#10 +
    '--config (string) path to config file' + #13#10 +
    '--newconfig (string) generates new config file';

  PROCESSCHARS : array of ShortInt = [$7C, $2F, $2D, $5C];

var
  consoleinfo, consolewarn, consoleerror, consolesuccess, consolelocalop, consoleproc, consoletarg : string;
  currentchar : Integer = 0;


  { TIOCore }

class function TIOCore.FileLen(const Path: string): Integer;
var
  f: file;
begin
  try
    AssignFile(f, Path);
    Reset(f);
    Result := FileSize(f);
  finally
    CloseFile(f);
  end;
end;

class procedure TIOCore.OnDirectoryCancel(Sender: TObject);
begin
  TConsole.Info('Directory Search is cancelled by user');
end;

class procedure TIOCore.OnDirectoryEnd(Sender: TObject);
begin
  TConsole.LocalOperation('No more sub-directories. Down. ');
  if Assigned(Sender) then TIOHandler(Sender).fftphandler.DownDirectory;
end;

class procedure TIOCore.OnDirectoryFound(Sender: TObject; const Path: string);
var
  moddate : TDateTime;
  datetoupload : TDateTime;
begin
  TConsole.LocalOperation('Directory Found : ' + path);
  moddate := TDirectory.GetLastWriteTime(Path);
  datetoupload := IncDay(Now, -AppConfig.DaysToUpload);
  TConsole.Info('Folder modification date : ' + DateTimeToStr(moddate));
  if (moddate > datetoupload) or (AppConfig.IgnoreLocalFolderModificationDate) or (AppConfig.Mirror) then
  begin
    //TConsole.Info('Get Files : ');
    try
      if Path.Contains('\') then
      begin
        if (Path.Substring(Path.LastIndexOf('\') + 1) <> '')  then
        begin
          TConsole.TargetOperation('Change FTP folder : ' + Path.Substring(Path.LastIndexOf('\') + 1));
          TIOHandler(Sender).fftphandler.ChangeFolder(Path.Substring(Path.LastIndexOf('\') + 1));
          TConsole.SuccessOperation('Change Folder Ok : ' + Path.Substring(Path.LastIndexOf('\') + 1));
        end;
        TIOHandler(Sender).GetFiles(Path);
      end;
    except
      on e : Exception do
      begin
        if e is TFTPDirectoryNotfoundException then
        begin
          try
            TConsole.ProcessInfo('Remote Folder is not exist : ' + Path.Substring(Path.LastIndexOf('\') + 1));
            TConsole.TargetOperation('Create folder : ' + Path.Substring(Path.LastIndexOf('\') + 1));
            TIOHandler(Sender).fftphandler.CreateFolder(Path.Substring(Path.LastIndexOf('\') + 1));
            TConsole.SuccessOperation('Because folder not found or cannot change we created the folder : ' + Path.Substring(Path.LastIndexOf('\') + 1));
            TConsole.TargetOperation('Change FTP folder : ' + Path.Substring(Path.LastIndexOf('\') + 1));
            TIOHandler(Sender).fftphandler.ChangeFolder(Path.Substring(Path.LastIndexOf('\') + 1));
            TConsole.SuccessOperation('Change Folder Ok : ' + Path.Substring(Path.LastIndexOf('\') + 1));
            TIOHandler(Sender).GetFiles(Path);
          except
            on e : Exception do Exit;
          end;
        end;
      end;
    end;
  end;
  Inc(TIOHandler(Sender).fprocesseddirectories);
end;

class procedure TIOCore.OnFileFound(Sender: TObject; const FilePath: string);
var
  moddate : TDateTime;
  datetoupload : TDateTime;
  datetoclean : TDateTime;
  daystoclean : TDateTime;
  moddateftpfile : TDateTime;
begin
  moddate := TFile.GetLastWriteTime(FilePath);
  datetoupload := IncDay(Now, -AppConfig.DaysToUpload);
  TConsole.LocalOperation('File Found : ' + FilePath);
  TConsole.Info('File modification date : ' + DateTimeToStr(moddate));
  //TConsole.Info('Modification date is newer than ? : ' + DateTimeToStr(datetoupload));
  if (moddate > datetoupload) or (AppConfig.Mirror) then
  begin
    //TConsole.SuccessOperation('Newer file found to upload');
    try
      //TConsole.Info('Let''s check if file exist on FTP... ');
      try
        moddateftpfile := TIOHandler(Sender).fftphandler.fftpclient.FileDate(TPath.GetFileName(FilePath));
        if (AppConfig.UploadDestOlder) or (moddate > moddateftpfile) then
        begin
          TConsole.Info('Remote file is older or not exist file will be uploaded : ' + FilePath);
          TIOHandler(Sender).fftphandler.UploadFile(FilePath);
          Inc(TIOHandler(Sender).fuploadedfiles);
          TConsole.SuccessOperation('File Uploaded! : ' + FilePath);
        end
        else TConsole.Info('Remote is same or newer than source file will not be uploaded : ' + FilePath);
      except
        on e : Exception do
        begin
          TConsole.Errors(e.Message);
          Exit;
        end;
      end;
    except
      on e : Exception do
      begin
        TConsole.Errors(e.Message);
        Exit;
      end;
    end;
  end
  else
  begin
    if AppConfig.CleanRemote then
    begin
      //TConsole.LocalOperation('File is older...');
      TConsole.Info('Let''s check if file exist on FTP and clean it from destination... ');
      try
        moddateftpfile := TIOHandler(Sender).fftphandler.fftpclient.FileDate(TPath.GetFileName(FilePath));
        if moddateftpfile <> 0 then
        begin
          daystoclean := IncDay(Now, -AppConfig.DaysToClean);
          //TConsole.Info('Modification FTP File is  : ' + DateTimeToStr(moddateftpfile));
          //TConsole.Info('Modification FTP filedate is newer than ? : ' + DateTimeToStr(daystoclean));
          if moddateftpfile < daystoclean then
          begin
            TConsole.TargetOperation('File can be deleted on destination : ' + DateTimeToStr(daystoclean));
            try
              TIOHandler(Sender).fftphandler.fftpclient.Delete(TPath.GetFileName(FilePath));
              TConsole.SuccessOperation('File deleted : ' + TPath.GetFileName(FilePath));
              Inc(TIOHandler(Sender).fdeletedfiles);
            except
              on e : Exception do
              begin
                TConsole.Errors(e.Message);
              end;
            end;
          end;
        end
        else
        begin
          TConsole.SuccessOperation('File not exists... delete is not necesary.');
        end;
      except
        on e : Exception do
        begin
          TConsole.Errors(e.Message);
        end;
      end;
    end;
  end;
  Inc(TIOHandler(Sender).fprocessedfiles);
end;

class procedure TIOCore.OnProcessEnd(Sender: TObject);
begin
  TConsole.SuccessOperation('Process finished. ');
  if not AppConfig.SendMail then Exit;
  with TQuickSMTP.Create do
  begin
    try
      NameFrom := AppConfig.ProgramEmail;
      MailFrom := AppConfig.ProgramEmail;
      MailHost := AppConfig.RelayHost;
      MailBody :=
      'QuickFTP Sync Status Report : ' + #10#13 +
      'Local Path : ' + TIOHandler(Sender).flocalpath + #10#13 +
      'Local Directories procesed : ' + TIOHandler(Sender).fprocesseddirectories.ToString + ' OF ' + TIOHandler(Sender).ftotaldirectories.ToString + #10#13 +
      'Local Files procesed : ' + TIOHandler(Sender).fprocessedfiles.ToString + ' OF ' + TIOHandler(Sender).ftotalfiles.ToString + #10#13 +
      'Files uploaded : ' + TIOHandler(Sender).fuploadedfiles.ToString + #10#13 +
      'Files deleted remote : ' + TIOHandler(Sender).fdeletedfiles.ToString + #10#13;
      MailSubject := 'QuickFTPSync Resume';
      ServerAuth := False;
      SMTPPort := 25;
      MailDest := AppConfig.EMailControlAddress;
      Logger.Info(MailBody);
      if not SendMail then raise Exception.Create('Error sending mail');
    finally
      Free;
    end;
  end;
end;


class procedure TIOCore.SourceCheck;
begin
  if AppConfig.LocalPath = '' then
  raise Exception.Create('Program halted. Source Directory is invalid or not defined : ' +
    AppConfig.LocalPath);
  if not TDirectory.Exists(AppConfig.LocalPath) then
    raise Exception.Create('Program halted. Source Directory does not exist : ' +
      AppConfig.LocalPath);
end;

{ TAPPCore }

class procedure TAppCore.IniThreadPool;
var
  threads: Integer;
begin
end;

class procedure TAppCore.PrintHelp;
begin
  Cout(HELP, TLogEventType.etInfo);
end;

class procedure TAppCore.Process;
begin
  try
    with TIOHandler.Create(TFTPHandler.Create) do
    begin
      try
        fprocessedfiles := 0;
        fprocesseddirectories := 0;
        ftotalfiles := 0;
        ftotaldirectories := 0;
        fnumofrootdirectories := 0;
        fnumtasks := 4;        
        OnDirectoriesFetch := TIOCore.OnDirectoryFound;
        OnDirectoriesCancel := TIOCore.OnDirectoryCancel;
        OnFileFound := TIOCore.OnFileFound;
        OnDirectoryEND := TIOCore.OnDirectoryEnd;
        OnProcessEnd := TIOCore.OnProcessEnd;
        fftphandler.Init;
        AppConfig.LocalPath := IncludeTrailingBackslash(AppConfig.LocalPath);
        GetDirectories(AppConfig.LocalPath, True, True);
      except
        on e : Exception do TConsole.Errors(e.Message);
      end;
    end;
  except
    on e : Exception do TConsole.Errors(e.Message);
  end;
end;

class procedure TAppCore.UpdateConsole;
begin
  ClearScreen;
  coutXY(0,1, 'Last error : ' + consoleerror, TLogEventType.etError);
  coutXY(0,3, 'Info : ' + consoleinfo, TLogEventType.etInfo);
  coutXY(0,6, 'Last source operation : ' + consolelocalop, TLogEventType.etWarning);
  coutXY(0,9, 'Last target operation : ' + consoletarg, TLogEventType.etWarning);
  coutXY(0,12,'Last successful operation : ' + consolesuccess, TLogEventType.etSuccess);
  coutXY(0,15, consoleproc, TLogEventType.etInfo);
  //Writeln(consoleproc);
end;

{ TArgCore }

class function TArgCore.ProcessArguments(Args: PAPPArguments): Boolean;
var
  ArgumentParser: TArgumentParser;
begin
  try
    ArgumentParser := TArgumentParser.Create;
    try
      ArgumentParser.AddArgument('--config', 'config', saStore);
      ArgumentParser.AddArgument('--newconfig', 'newconfig', saStore);
      ArgumentParser.AddArgument('--help', 'help', saBool);
      with ArgumentParser.ParseArgs do
      try
        begin
          Result := True;
          if HasArgument('help') then
          begin
            TAppCore.PrintHelp;
            raise Exception.Create('Program halted. Help method.');
          end
          else if HasArgument('newconfig') then
            TConfigCore.NewConfig(GetValue('newconfig'))
          else if HasArgument('config') then
            TConfigCore.LoadConfig(GetValue('config'))
          else
            raise Exception.Create('Halt, no parameters.');
        end;
      finally
        Free;
      end;
    except
      on e: Exception do
      begin
        Result := False;
        raise Exception.Create('Program startup failed : ' + e.Message);
      end;
    end;
  finally
    ArgumentParser.Free;
  end;
end;

{ TConfigCore }

class procedure TConfigCore.LoadConfig(const ConfigPath: string);
begin
  if FileExists(ConfigPath) then
  begin
    try
      AppConfig := TConfig.Load(ConfigPath);
      //cout(AppConfig.AsJsonString, etInfo);
    except
      on e: Exception do
        raise Exception.Create(e.Message);
    end;
  end;
end;

class procedure TConfigCore.NewConfig(const ConfigPath: string);
begin
  AppConfig := TConfig.Create;
  try
    AppConfig.Save;
  except
    on e: Exception do raise Exception.Create(e.ToString);
  end;
end;

class procedure TConfigCore.ValidateConfig;
begin
  try
    if Assigned(AppConfig) then
    begin
      if AppConfig.FTPHost = '' then
        raise Exception.Create('FTPHost line is empty')
      else if AppConfig.LocalPath = '' then
        raise Exception.Create('FTPHost line is empty')
      else if AppConfig.FTPUser = '' then
        raise Exception.Create('FTPUser is empty')
      else if AppConfig.LocalPath = '' then
        raise Exception.Create('Local Path is empty');
    end
    else
      raise Exception.Create('Config file is malformed or/and invalid');
  except
    on e: Exception do
      raise Exception.Create('Config : ' + e.Message);
  end;
end;

{ TIOHandler }


constructor TIOHandler.Create(FTPHandler: TFTPHandler);
begin
  ftasks := TBackgroundTasks.Create(8);
  fstarttime := Now;
  fftphandler := FTPHandler.Create;
  fftphandler.fioretries := 5;
  fend := False;
  TAnonymousThread.Execute(
  procedure
  begin
    while not fend do
    begin
      PrintStatus;
      Sleep(60);
    end;
  end
  ).Start;
end;

procedure TIOHandler.EndJob;
begin
  fftphandler.FEndWork := True;
end;

procedure TIOHandler.GetDirectories(const Path: string; Recurse: Boolean; IsRootPath : Boolean);
var
  currentpath : string;
  founddirectory : string;
  fdirectories : TStringDynArray;
  start : Integer;
  finish : Integer;
  chunksize : Integer;
  a : integer;
  currenttask : Integer;
begin
  try
    if flocalpath = '' then flocalpath := Path;
    if not TDirectory.Exists(Path) then raise Exception.Create('Couldn''t find specified directory.');
    fdirectories := TDirectory.GetDirectories(Path);
    if fdirectories <> nil then
    begin
      if IsRootPath then fnumofrootdirectories := High(fdirectories);
      Inc(ftotaldirectories, High(fdirectories));
    end;
    begin
      for founddirectory in fdirectories do
      begin
        if not fcancel then
        begin
          //Para los recursivos
          if Assigned(fondirecotriesfetch) then fondirecotriesfetch(Self, founddirectory);
          if Recurse then Self.GetDirectories(founddirectory, Recurse, False);
          if Assigned(fondirectoryend) then fondirectoryend(Self);
        end
        else
        begin
          if Assigned(foncancel) then foncancel(self);
          Break;
        end;
      end;
    end;
    //Si es el primer path el raiz entonces procesa también los ficheros en el FTP también debería estar en raiz
    if IsRootPath then
    begin
      fondirecotriesfetch(Self, path);
      //Como es el primer nivel de recursividad acabamos...
      fendtime := Now;
      fend := True;
      if Assigned(fonprocessend) then fonprocessend(Self);
    end;
  except
    on e : Exception do raise Exception.Create('IO Error : ' + e.Message);
  end;
end;

procedure TIOHandler.GetFiles(const Path: string);
var
  foundfile : string;
  ffoundfiles : TStringDynArray;
begin
  ffoundfiles := TDirectory.GetFiles(Path);
  if ffoundfiles <> nil then Inc(ftotalfiles, High(ffoundfiles));
  for foundfile in ffoundfiles do
  begin
    if Assigned(fonfilefound) then fonfilefound(Self, foundfile);
  end;
end;

procedure TIOHandler.PrintStatus;
begin
  var processedfiles := fprocessedfiles.ToString;
  var totalfiles := ftotalfiles.ToString;
  var uploadedfiles := fuploadedfiles.ToString;
  var deletedfiles := fdeletedfiles.ToString;
  var processeddirectories := fprocesseddirectories.ToString;
  var totaldirectories := ftotaldirectories.ToString;

  TConsole.ProcessInfo(Format('Processed Directories : %s/%s' + #10#13 + 'Processed Files : %s/%s' + #10#13 + 'Uploaded Files : %s' + #10#13 + 'Deleted Files : %s ' + #10#13#13 + '%s', [processeddirectories, totaldirectories,
  processedfiles, totalfiles, uploadedfiles, deletedfiles, Char(PROCESSCHARS[currentchar])]));
  Inc(currentchar);
  if currentchar > High(PROCESSCHARS) then currentchar := 0;
end;

procedure TIOHandler.SetCurrentDirectory(const Value: string);
begin
  FCurrentDirectory := Value;
end;

{ TFTPHandler }

procedure TFTPHandler.ChangeFolder(const Folder: string);
begin
  var t := 1;
  var changed := False;
  while (t < fioretries) and not changed do
  begin
    try    
      fcurrentdirectory := Folder;
      try
        fftpclient.ChangeDir(Folder);
      except
        on e : Exception do
        begin
          if not e.Message.ToLower.Contains('successful') then raise Exception.Create(e.Message);
        end;
      end;
      changed := True;
    except
      on e : Exception do
      begin
        TConsole.Errors('[TFTPHandler] >> FTP error while changing directory -> ' + Folder + ' ' + e.Message);
        if e.Message.ToLower.Contains('not found') then raise TFTPDirectoryNotfoundException.Create('FTP Folder not found ' + Folder);
      end;
    end;
    Inc(t);
  end;
  if not changed then raise TFTPDirectoryNotfoundException.Create('FTP Folder not found ' + Folder);
end;

procedure TFTPHandler.CheckConnection;
begin
  var t := 1;
  while (t < fioretries) and not (fftpclient.Connected) do
  begin
    try
      TConsole.ProcessInfo('[TFTPHandler] >> FTP is not connected, trying to connect, try : ' + t.ToString);
      Init;
    except
      on e : Exception do
      begin
        TConsole.Errors('[TFTPHandler] >> FTP error while connecting ' + e.Message);        
      end;  
    end;
    Inc(t);    
    Sleep(1000)    
  end;
  if not fftpclient.Connected then raise Exception.Create('FTP is not connected and tries exceed');
end;

constructor TFTPHandler.Create;
begin

end;

procedure TFTPHandler.CreateFolder(const Folder: string);
begin
  var t := 1;
  var created := False;
  while (t < fioretries) and not (created) do
  begin
    try      
      fftpclient.MakeDir(Folder);  
      created := True;
    except
      on e : Exception do
      begin
        TConsole.Errors('[TFTPHandler] >> FTP error while changing directory ' + e.Message);        
      end;  
    end;
    Inc(t);    
  end;
  if not created then raise TFTPDirectoryCantCreateException.Create('Cannot create FTP folder ' + Folder);
end;

procedure TFTPHandler.DownDirectory;
begin
  var t := 1;
  var down := False;
  while (t < fioretries) and not (down) do
  begin
    try      
      fftpclient.ChangeDir('..');
      fcurrentdirectory := '';
      down := True;
    except
      on e : Exception do
      begin
        TConsole.Errors('[TFTPHandler] >> FTP error while down .. directory ' + e.Message);        
      end;  
    end;
    Inc(t);    
  end;
  if not down then raise TFTPDirectoryCantDown.Create('Cannot down FTP directory');
end;

procedure TFTPHandler.Init;
begin
  if fftpclient <> nil then fftpclient.Free;  
  fftpclient := TIdFTP.Create(nil);
  fftpclient.Host := AppConfig.FTPHost;
  fftpclient.TransferType := TIdFTPTransferType.ftBinary;
  fftpclient.OnConnected := Self.OnFTPConnected;
  fftpclient.OnDisconnected := Self.OnFTPDisconnected;  
  fftpclient.Username := AppConfig.FTPUser;
  fftpclient.Password := AppConfig.FTPPassword;
  fftpclient.AutoLogin := False;
  fislogged := False;
  fftpclient.Connect;
  fftpclient.Login;
  fislogged := True;
//  if fcurrentdirectory <> '' then
//  begin
//    var remotedirectory := fftpclient.RetrieveCurrentDir.ToLower;
//    TConsole.TargetOperation(Format('Last FTP folder before disconnection was %s, now is %s, return to last directory', [fcurrentdirectory, remotedirectory]));
//    if not remotedirectory.Contains(fcurrentdirectory) then
//    begin
//      TConsole.TargetOperation(Format('We need to change current directory to %s, now is %s', [fcurrentdirectory, remotedirectory]));
//      ChangeFolder(fcurrentdirectory);
//      fcurrentdirectory := '';
//    end;
//  end;
end;

procedure TFTPHandler.OnFileNotUploaded(Sender: TObject;
  const Filename: string);
begin
  TConsole.Errors('File not uploaded ' + Filename);
end;

procedure TFTPHandler.OnFileUploaded(Sender: TObject; const Filename: string);
begin
  TConsole.SuccessOperation('File uploaded ' + Filename);
end;

procedure TFTPHandler.OnFTPConnected(Sender: TObject);
begin
  fftpclient.PassiveUseControlHost := True;
  fftpclient.Passive := True; 
  TConsole.SuccessOperation('FTP Connected !');      
end;

procedure TFTPHandler.OnFTPDisconnected(Sender: TObject);
begin
  if not EndWork then 
  begin
    TConsole.Errors('FTP Premature disconnection !');
    CheckConnection;
  end
  else TConsole.TargetOperation('FTP Disconnected.');
end;

procedure TFTPHandler.OnFTPFolderCantCreate(Sender: TObject; const Folder: string);
begin
  //
end;

procedure TFTPHandler.OnFTPFolderChanged(Sender: TObject; const Folder: string);
begin
  TConsole.SuccessOperation('FTP Folder changed : ' + folder);
end;

procedure TFTPHandler.OnFTPFolderFound(Sender: TObject; const Folder: string);
begin
  TConsole.SuccessOperation('FTP Folder found : ' + folder);
end;

procedure TFTPHandler.OnFTPWork(Sender: TObject; Astatus: TIdStatus;
  const AText: string);
begin
  //
end;

procedure TFTPHandler.OnFTPWorkStart(Sender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
  //
end;

procedure TFTPHandler.SetEndWork(const Value: Boolean);
begin
  FEndWork := Value;
end;

procedure TFTPHandler.UploadFile(const Path: string);
begin
  CheckConnection;
  var uploaded := False;
  var t := 1;
  while (t < fioretries) and not uploaded do
  begin
    try
      TConsole.TargetOperation('Uploading File : ' + Path);
      fftpclient.Put(path, TPath.GetFileName(path), False);
      uploaded := True;        
    except
      on e : Exception do
      begin
        TConsole.Errors('[TFTPHandler] >> Error while upload file ' + Path);
        Inc(t);
      end;
    end;
  end;
  if not uploaded then raise Exception.Create('FTP errors is and tries exceed');  
end;

{ TConsole }

class procedure TConsole.Errors(const Msg: string);
begin
  consoleerror := Msg;
  Logger.Error(Msg);
end;

class procedure TConsole.Info(const Msg: string);
begin
  consoleinfo := Msg;
end;

class procedure TConsole.LocalOperation(const Msg: string);
begin
  consolelocalop := Msg;
end;

class procedure TConsole.ProcessInfo(const Msg: string);
begin
  consoleproc := Msg;
end;

class procedure TConsole.SuccessOperation(const Msg: string);
begin
  consolesuccess := Msg;
  Logger.Succ(msg);
end;

class procedure TConsole.TargetOperation(const Msg: string);
begin
  consoletarg := Msg;
  Logger.Info(Msg);
end;

end.
