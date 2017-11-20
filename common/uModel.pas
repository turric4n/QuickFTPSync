unit uModel;

interface

type

  TAPPArguments = record
    configfile : string;
    help : Boolean;
    badarguments : Boolean;
  end;

  PAPPArguments = ^TAPPArguments;

  TJOBTrace = record
    localdirectoryexists : Boolean;
    ftpexists : Boolean;
    ftpconnected : Boolean;
  end;

  PJOBTrace = ^TJOBTrace;

implementation
	
end.