object Form1: TForm1
  Left = 192
  Top = 107
  Width = 239
  Height = 310
  Caption = 'CargaLauncher'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label2: TLabel
    Left = 16
    Top = 240
    Width = 43
    Height = 13
    Caption = 'Contador'
  end
  object Label4: TLabel
    Left = 72
    Top = 240
    Width = 32
    Height = 13
    Caption = 'Label4'
  end
  object Label1: TLabel
    Left = 80
    Top = 256
    Width = 8
    Height = 13
    Caption = '%'
  end
  object Button1: TButton
    Left = 64
    Top = 208
    Width = 75
    Height = 25
    Caption = 'Parar'
    Enabled = False
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 64
    Top = 176
    Width = 75
    Height = 25
    Caption = 'Come'#231'ar'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Edit1: TEdit
    Left = 72
    Top = 16
    Width = 121
    Height = 21
    TabOrder = 2
    Text = 'desenv3.prognum.int'
  end
  object Edit2: TEdit
    Left = 72
    Top = 40
    Width = 121
    Height = 21
    TabOrder = 3
    Text = '17005'
  end
  object Edit3: TEdit
    Left = 72
    Top = 96
    Width = 121
    Height = 21
    TabOrder = 4
    Text = 'clicio'
  end
  object Edit4: TEdit
    Left = 72
    Top = 120
    Width = 121
    Height = 21
    PasswordChar = '*'
    TabOrder = 5
  end
  object Edit5: TEdit
    Left = 72
    Top = 67
    Width = 121
    Height = 21
    TabOrder = 6
    Text = '/home/clicio/scci/launcher'
  end
  object CheckBox1: TCheckBox
    Left = 72
    Top = 152
    Width = 97
    Height = 17
    Caption = 'Testa Escrita'
    TabOrder = 7
  end
  object pCCPClient1: TpCCPClient
    KeepConnection = False
    Connected = False
    CursorHourGlass = False
    Left = 8
    Top = 16
  end
end
