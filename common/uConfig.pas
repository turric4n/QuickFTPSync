unit uConfig;


interface

uses
  System.Classes,
  System.SysUtils,
  {$IF CompilerVersion >= 32.0}
  System.JSON.Types,
  System.JSON.Serializers;
  {$ELSE}
  Rest.Json.Types,
  Rest.Json;
  {$ENDIF}

type
  [JsonSerialize(TJsonMemberSerialization.&Public)]
  TConfig = class
    private
      [JSONMarshalledAttribute(False)]
      fConfigFile : string;
      [JSONMarshalledAttribute(False)]
      fConfigEncrypted : Boolean;
      [JSONMarshalledAttribute(False)]
      fConfigPassword : string;
      FRelayHost: string;
      FLocalPath: string;
      FOverwrite: Boolean;
      FClean: Boolean;
      FDaysToClean: Integer;
      FEMailControlAddress: string;
      FDebug: Boolean;
      FProgramEmail: string;
      FSendMail: Boolean;
      FMirror: Boolean;
      FFTPPassword: string;
      FDaysToUpload: Integer;
      FFTPHost: string;
      FFTPUser: string;
      FThreads: Integer;
      fuploaddestolder : Boolean;
    public
      property ConfigFile : string read fConfigFile;
      [JsonIgnoreAttribute]
      property ConfigEncrypted : Boolean read fConfigEncrypted write fConfigEncrypted;
      [JsonIgnoreAttribute]
      property ConfigPassword : string read fConfigPassword write fConfigPassword;
      class function Load(const ConfigPath : string) : TConfig;
      procedure Save;
      function AsJsonString : string;
      property FTPHost: string read FFTPHost write FFTPHost;
      property FTPPassword: string read FFTPPassword write FFTPPassword;
      property FTPUser: string read FFTPUser write FFTPUser;
      property LocalPath: string read FLocalPath write FLocalPath;
      property ProgramEmail: string read FProgramEmail write FProgramEmail;
      property EMailControlAddress: string read FEMailControlAddress write FEMailControlAddress;
      property Debug: Boolean read FDebug write FDebug;
      property Mirror: Boolean read FMirror write FMirror;
      property Overwrite: Boolean read FOverwrite write FOverwrite;
      property DaysToClean: Integer read FDaysToClean write FDaysToClean;
      property DaysToUpload: Integer read FDaysToUpload write FDaysToUpload;
      property Clean: Boolean read FClean write FClean;
      property SendMail: Boolean read FSendMail write FSendMail;
      property RelayHost: string read FRelayHost write FRelayHost;
      property UploadDestOlder : Boolean read fuploaddestolder write fuploaddestolder;
      property Threads: Integer read FThreads write FThreads;
  end;

implementation

class function TConfig.Load(const ConfigPath : string) : TConfig;
var
  json : TStrings;
  {$IF CompilerVersion >= 32.0}
    Serializer : TJsonSerializer;
  {$ENDIF}
begin
  try
    json := TStringList.Create;
    try
      json.LoadFromFile(ConfigPath);
      {$IF CompilerVersion >= 32.0}
      Serializer := TJsonSerializer.Create;
      try
        Result := Serializer.Deserialize<TConfig>(json.Text);
      finally
        Serializer.Free;
      end;
      {$ELSE}
      Self := TJson.JsonToObject<TConfig>(json.Text)
      {$ENDIF}
    finally
      json.Free;
    end;
  except
    on e : Exception do raise Exception.Create(e.Message);
  end;
end;

procedure TConfig.Save;
var
  json : TStrings;
  {$IF CompilerVersion >= 32.0}
    Serializer : TJsonSerializer;
  {$ENDIF}
begin
  try
    json := TStringList.Create;
    try
      {$IF CompilerVersion >= 32.0}
      Serializer := TJsonSerializer.Create;
      try
        Serializer.Formatting := TJsonFormatting.Indented;
        json.Text := Serializer.Serialize(Self);
      finally
        Serializer.Free;
      end;
      {$ELSE}
      json.Text := TJson.ObjectToJsonString(Self);
      {$ENDIF}
      json.SaveToFile(fConfigFile);
    finally
      json.Free;
    end;
  except
    on e : Exception do raise Exception.Create(e.Message);
  end;
end;

function TConfig.AsJsonString : string;
{$IF CompilerVersion >= 32.0}
  var
    Serializer: TJsonSerializer;
{$ENDIF}
begin
  Result := '';
  {$IF CompilerVersion >= 32.0}
  Serializer := TJsonSerializer.Create;
  try
    Serializer.Formatting := TJsonFormatting.Indented;
    Result := Serializer.Serialize(Self);
  finally
    Serializer.Free;
  end;
  {$ELSE}
  Result := TJson.ObjectToJsonString(Self);
  {$ENDIF}
end;
end.