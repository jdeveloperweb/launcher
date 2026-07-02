unit Ucargalauncher;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ucommunication, StdCtrls;

type
  TForm1 = class(TForm)
    pCCPClient1: TpCCPClient;
    Button1: TButton;
    Button2: TButton;
    Label2: TLabel;
    Label4: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Label1: TLabel;
    CheckBox1: TCheckBox;
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    FTemQueParar : boolean;
    FContador : Integer;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button2Click(Sender: TObject);
var
        Inicio: TDateTime;
begin
  Button2.Enabled := false;
  Button1.Enabled := true;
  FTemQueParar := false;
  FContador := 0;
  Inicio := now;
  randomize;
  try
    while not FTemQueParar do
    begin
      inc(FContador);
      Label4.Caption := inttostr(FContador);
      Application.ProcessMessages;
//    sleep(100);
      pCCPClient1.Params.Values['Server']:=Edit1.Text;
      pCCPClient1.Params.Values['Socket']:=Edit2.Text;
      if not CheckBox1.Checked then pCCPClient1.Params.Values['ServerPath']:=Edit5.Text
      else pCCPClient1.Params.Values['ServerPath']:=Edit5.Text+'/base'+inttostr(trunc(random(1000)));
      pCCPClient1.Login(Edit3.Text,Edit4.Text);
    end;
    Label1.Caption := 'Feitas '+inttostr(FContador)+ ' em '+formatdatetime( 'nn:ss:z',now-Inicio)+' s ';
  finally
    Button2.Enabled := true;
    Button1.Enabled := false;
  end;

end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  FTemqueParar := true;
end;

end.
