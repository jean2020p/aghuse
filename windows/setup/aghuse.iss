; ============================================================================
;  AGHUse 13.250-STABLE - Instalador grafico para Windows (Inno Setup 6.3+)
;  Gerado por windows\setup\gerar-setup.ps1 (passa /DBuildDir=... ao ISCC).
;
;  Instalacao completa SEM INTERNET: o .exe traz OpenJDK 17, WildFly 26.1.3,
;  PostgreSQL 15, a aplicacao (aghu.ear) e a base inicial. Ambiente de TESTE
;  PRE-CONFIGURADO: nada a preencher (LDAP local com AD LDS, administrador AGHU
;  com senha gerada, porta 8080, pasta C:\AGHUse). Telas: aviso -> autenticacao (LDAP local
;  recomendado ou banco) -> requisitos ->
;  [outros sistemas] -> resumo -> instalacao -> resultado. O instalador grava
;  {app}\ferramentas\aghuse.conf e executa o motor instalar.ps1 (mesma logica do
;  instalar.sh do Linux). Outra configuracao: edite aghuse.conf e rode instalar.bat
;  (ou, sem telas: /SILENT /MODO=banco /PORTA=8180 /RECRIAR=sim ...).
;  Sem chave de ativacao/licenca: software publico (GPL v2).
; ============================================================================

#ifndef BuildDir
  #define BuildDir "build"
#endif
#ifndef OutDir
  #define OutDir "saida"
#endif
#define MyAppName "AGHUse"
#define MyAppVersion "13.250-STABLE"
#define Servico "aghuse"
; Variante NAO OFICIAL (gerar-setup.ps1 -Variante): VarianteNome e VarianteSufixo vem do arquivo VARIANTE
#ifndef VarianteSufixo
  #define VarianteSufixo ""
#endif
#ifdef VarianteNome
  #define Rotulo VarianteNome
#else
  #define Rotulo "teste e estudo"
#endif

[Setup]
AppId={{5E0A7C3B-6C1D-4E8A-9B7F-2D4C8A1E6F30}
AppName={#MyAppName} {#MyAppVersion}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion} ({#Rotulo})
AppPublisher=Instalador independente (sem vinculo com HCPA/EBSERH)
AppPublisherURL=https://github.com/jean2020p/aghuse
AppComments=Aplicativo para Gestao Hospitalar - pacote para TESTE e ESTUDO, sem garantia e sem suporte.
DefaultDirName=C:\AGHUse
DisableDirPage=yes
DefaultGroupName=AGHUse
DisableProgramGroupPage=yes
AllowNoIcons=yes
OutputDir={#OutDir}
OutputBaseFilename=aghuse_setup_{#MyAppVersion}{#VarianteSufixo}_Windows
LicenseFile=AVISO.txt
SetupIconFile=aghuse.ico
UninstallDisplayIcon={app}\aghuse.ico
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
WizardStyle=modern
WizardSizePercent=110
Compression=lzma2/normal
SolidCompression=no
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=4
CloseApplications=no
RestartIfNeededByRun=no
#ifdef VarianteNome
UninstallDisplayName={#MyAppName} {#MyAppVersion} ({#VarianteNome})
#else
UninstallDisplayName={#MyAppName} {#MyAppVersion}
#endif
SetupLogging=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "aghuse.ico"; DestDir: "{app}"; Flags: ignoreversion
; ferramentas: motor de instalacao e utilitarios (ficam instalados)
Source: "..\instalar.ps1";    DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\usuario.ps1";     DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\verificar.ps1";   DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\desinstalar.ps1"; DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\*.bat";           DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\lib\comum.ps1";   DestDir: "{app}\ferramentas\lib"; Flags: ignoreversion
Source: "..\lib\ldaplocal.ps1"; DestDir: "{app}\ferramentas\lib"; Flags: ignoreversion
Source: "..\..\README.md";    DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\..\LICENSE";      DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\..\docs\CADASTRO_DE_USUARIOS.md"; DestDir: "{app}\ferramentas"; Flags: ignoreversion
#ifdef VarianteNome
; variante: identificacao e resumo do que mudou (codigo-fonte, patch e testes ficam no repositorio)
Source: "{#BuildDir}\VARIANTE"; DestDir: "{app}\ferramentas"; Flags: ignoreversion
Source: "..\..\modificacoes\integracao-ldap\README.md"; DestDir: "{app}\ferramentas\modificacoes\integracao-ldap"; Flags: ignoreversion
Source: "..\..\modificacoes\integracao-ldap\tela-trocar-senha.png"; DestDir: "{app}\ferramentas\modificacoes\integracao-ldap"; Flags: ignoreversion
#endif
; componentes ja extraidos (o motor detecta e nao baixa nada)
Source: "{#BuildDir}\jdk-17.0.2\*"; DestDir: "{app}\jdk-17.0.2"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#BuildDir}\pgsql\*";      DestDir: "{app}\pgsql";      Flags: recursesubdirs createallsubdirs ignoreversion uninsneveruninstall
; pacote da aplicacao e WildFly: usados durante a instalacao e apagados ao final
Source: "{#BuildDir}\pacote\*"; DestDir: "{app}\ferramentas\pacote"; Flags: ignoreversion nocompression deleteafterinstall
Source: "{#BuildDir}\dependencias\wildfly\*"; DestDir: "{app}\ferramentas\dependencias\wildfly"; Flags: ignoreversion nocompression deleteafterinstall


[Icons]
Name: "{group}\AGHUse";                     Filename: "{app}\Acessar o AGHUse.url"; IconFilename: "{app}\aghuse.ico"; Comment: "Abrir o AGHUse no navegador (http://localhost)"
Name: "{group}\Como cadastrar usuarios";    Filename: "{win}\notepad.exe"; Parameters: """{app}\ferramentas\CADASTRO_DE_USUARIOS.md"""; Comment: "Passo a passo: conta de acesso + cadastro no AGHUse"
Name: "{group}\Credenciais da instalacao";  Filename: "{win}\notepad.exe"; Parameters: """{commonappdata}\AGHUse\aghuse-credenciais-{#Servico}.txt"""; Comment: "Senha do administrador e do banco (somente Administradores)"
Name: "{group}\Verificar a instalacao";     Filename: "{app}\ferramentas\verificar.bat"; IconFilename: "{app}\aghuse.ico"
Name: "{group}\Pasta de logs do AGHUse";    Filename: "{app}\wildfly-26.1.3.Final\standalone\log"
Name: "{group}\Desinstalar o AGHUse";       Filename: "{uninstallexe}"; IconFilename: "{app}\aghuse.ico"
Name: "{autodesktop}\AGHUse";               Filename: "{app}\Acessar o AGHUse.url"; IconFilename: "{app}\aghuse.ico"; Comment: "Abrir o AGHUse no navegador (http://localhost)"

[Run]
Filename: "{win}\notepad.exe"; Parameters: """{code:CredFinal}"""; Description: "Abrir o arquivo de credenciais (senha do administrador)"; Flags: postinstall nowait skipifsilent; Check: InstalouOk
Filename: "{code:UrlLocal}"; Description: "Abrir o AGHUse no navegador (http://localhost)"; Flags: shellexec postinstall nowait skipifsilent; Check: InstalouOk
Filename: "{win}\notepad.exe"; Parameters: """{commonappdata}\AGHUse\logs\aghuse-instalador-{#Servico}.log"""; Description: "Abrir o log da instalacao"; Flags: postinstall nowait skipifsilent; Check: InstalouFalhou

[UninstallDelete]
Type: files; Name: "{app}\Acessar o AGHUse.url"
Type: filesandordirs; Name: "{app}\ferramentas"
Type: dirifempty; Name: "{app}"

[Code]
const
  RAM_MIN_GB = 12;     RAM_REC_GB = 16;     { Windows: SO ~2,5 GB + WildFly ~6,5 GB + PostgreSQL }
  DISCO_MIN_GB = 20;   DISCO_REC_GB = 100;
  NUCLEOS_REC = 4;

var
  ReqPage: TOutputMsgMemoWizardPage;
  LoginPage: TInputOptionWizardPage;
  AceitePage: TWizardPage;
  AceiteMemo: TNewMemo;
  AceiteCheck: TNewCheckBox;
  AceiteRegistro: String;
  ReqBloqueio: String;
  RamGB, Nucleos: Integer;
  Saida, UltimoErro, Url, UrlLoc, Cred, EtapaAtual, SenhaAdmin: String;
  Sucesso, Executou: Boolean;

{ ---------------------------------------------------------------- utilitarios }

function Silencioso(): Boolean;
begin
  Result := WizardSilent();
end;

function ParamOuPadrao(const Nome, Padrao: String): String;
begin
  Result := ExpandConstant('{param:' + Nome + '|' + Padrao + '}');
end;

function SomenteAlfanum(const S: String): Boolean;
var i: Integer; c: Char;
begin
  Result := True;
  for i := 1 to Length(S) do begin
    c := S[i];
    if not (((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z')) or ((c >= '0') and (c <= '9'))) then begin
      Result := False; exit;
    end;
  end;
end;

{ Configuracao pre-definida (ambiente de teste). Parametros opcionais de linha de comando
  permitem outra configuracao sem telas: /MODO= /ADMIN= /PORTA= /MEMORIA= /RECRIAR= /FIREWALL= /PROXY= }
{ Modo de login: tela "Autenticacao" (LDAP local recomendado, ou banco de dados). Sem telas
  (modo silencioso) ou com /MODO=ldap-externo, vale o parametro /MODO= (padrao ldap-local). }
function ModoLogin(): String;
begin
  Result := Lowercase(ParamOuPadrao('MODO', 'ldap-local'));
  if (Result <> 'banco') and (Result <> 'ldap-externo') then Result := 'ldap-local';
  if (Result <> 'ldap-externo') and (LoginPage <> nil) then begin
    if LoginPage.SelectedValueIndex = 1 then Result := 'banco' else Result := 'ldap-local';
  end;
end;

function AdminLogin(): String;
begin
  Result := ParamOuPadrao('ADMIN', 'AGHU');
end;

function PortaHttp(): Integer;
begin
  Result := StrToIntDef(ParamOuPadrao('PORTA', '8080'), 8080);
  if (Result < 8080) or (Result > 8999) then Result := 8080;
end;

function ServiceExists(const Nome: String): Boolean;
var rc: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\sc.exe'), 'query "' + Nome + '"', '', SW_HIDE, ewWaitUntilTerminated, rc) and (rc = 0);
end;

function PortaEmUso(Porta: Integer): Boolean;
var rc: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), '/c netstat -an -p TCP | findstr /r /c:":' + IntToStr(Porta) + ' .*LISTENING" >nul', '',
                 SW_HIDE, ewWaitUntilTerminated, rc) and (rc = 0);
end;

procedure LerHardware();
var Loc, Svc, Lista, Item: Variant; Bytes: String;
begin
  RamGB := 0; Nucleos := 0;
  try
    Loc := CreateOleObject('WbemScripting.SWbemLocator');
    Svc := Loc.ConnectServer('.', 'root\CIMV2');
    Lista := Svc.ExecQuery('SELECT TotalPhysicalMemory, NumberOfLogicalProcessors FROM Win32_ComputerSystem');
    Item := Lista.ItemIndex(0);
    Bytes := Item.TotalPhysicalMemory;
    RamGB := Round(StrToFloat(Bytes) / 1073741824.0);
    Nucleos := Item.NumberOfLogicalProcessors;
  except
    RamGB := 0; Nucleos := 0;
  end;
end;

function DiscoLivreGB(const Pasta: String): Integer;
var Livre, Total: Int64;
begin
  Result := -1;
  if GetSpaceOnDisk64(ExtractFileDrive(Pasta), Livre, Total) then
    Result := Livre div 1073741824;
end;

{ Verifica requisitos minimos; devolve o texto do relatorio e preenche ReqBloqueio }
var RelReq: String;

procedure Linha(const Situacao, Texto: String);
begin
  RelReq := RelReq + '  [' + Situacao + ']  ' + Texto + #13#10;
end;

function VerificarRequisitos(const Pasta: String): String;
var
  V: TWindowsVersion; Livre: Integer;
begin
  ReqBloqueio := ''; RelReq := '';
  LerHardware();
  GetWindowsVersionEx(V);

  if IsWin64 then Linha('OK', 'Sistema de 64 bits (x64)')
  else begin Linha('FALHA', 'O AGHUse requer Windows de 64 bits'); ReqBloqueio := ReqBloqueio + '- Windows de 64 bits'#13#10; end;

  if (V.Major > 10) or ((V.Major = 10) and (V.Build >= 17763)) then
    Linha('OK', Format('Windows %d.%d build %d (minimo: Windows 10 1809 / Server 2019)', [V.Major, V.Minor, V.Build]))
  else begin
    Linha('FALHA', Format('Windows build %d: requer Windows 10 1809 / Server 2019 ou superior', [V.Build]));
    ReqBloqueio := ReqBloqueio + '- Windows 10 1809 / Server 2019 ou superior'#13#10;
  end;

  if RamGB = 0 then Linha('AVISO', 'Nao foi possivel ler a memoria RAM (o instalador confere novamente)')
  else if RamGB < RAM_MIN_GB then begin
    Linha('FALHA', Format('Memoria RAM: %d GB (minimo %d GB; recomendado %d GB)', [RamGB, RAM_MIN_GB, RAM_REC_GB]));
    ReqBloqueio := ReqBloqueio + Format('- Memoria RAM de pelo menos %d GB (a maquina tem %d GB)'#13#10, [RAM_MIN_GB, RamGB]);
  end else if RamGB < RAM_REC_GB then
    Linha('AVISO', Format('Memoria RAM: %d GB (funciona, com pouca folga; recomendado %d GB)', [RamGB, RAM_REC_GB]))
  else Linha('OK', Format('Memoria RAM: %d GB', [RamGB]));

  if Nucleos = 0 then Linha('AVISO', 'Nao foi possivel ler o numero de processadores')
  else if Nucleos < NUCLEOS_REC then Linha('AVISO', Format('Processadores: %d (recomendado %d ou mais; o sistema ficara lento)', [Nucleos, NUCLEOS_REC]))
  else Linha('OK', Format('Processadores: %d', [Nucleos]));

  Livre := DiscoLivreGB(Pasta);
  if Livre < 0 then Linha('AVISO', 'Nao foi possivel ler o espaco livre em disco')
  else if Livre < DISCO_MIN_GB then begin
    Linha('FALHA', Format('Espaco livre em %s: %d GB (minimo %d GB; recomendado %d GB)', [ExtractFileDrive(Pasta), Livre, DISCO_MIN_GB, DISCO_REC_GB]));
    ReqBloqueio := ReqBloqueio + Format('- Pelo menos %d GB livres em %s'#13#10, [DISCO_MIN_GB, ExtractFileDrive(Pasta)]);
  end else if Livre < DISCO_REC_GB then
    Linha('AVISO', Format('Espaco livre em %s: %d GB (recomendado %d GB para dados, logs e backups)', [ExtractFileDrive(Pasta), Livre, DISCO_REC_GB]))
  else Linha('OK', Format('Espaco livre em %s: %d GB', [ExtractFileDrive(Pasta), Livre]));

  if ServiceExists('{#Servico}') then Linha('OK', 'AGHUse ja instalado: sera reinstalado mantendo os dados')
  else if PortaEmUso(PortaHttp()) then Linha('AVISO', Format('A porta %d ja esta em uso por outro programa: o AGHUse pode nao iniciar', [PortaHttp()]))
  else Linha('OK', Format('Porta %d livre', [PortaHttp()]));
  if (ModoLogin() = 'ldap-local') and not ServiceExists('ADAM_{#Servico}ldap') and (PortaEmUso(50389) or PortaEmUso(50636)) then begin
    Linha('FALHA', 'As portas 50389/50636 (LDAP local) ja estao em uso por outro programa');
    ReqBloqueio := ReqBloqueio + '- Portas 50389 e 50636 livres para o LDAP local'#13#10;
  end;
  if PortaEmUso(5432) then Linha('AVISO', 'Ja existe um servico na porta 5432 (outro PostgreSQL?). O AGHUse usara outra porta, mas a maquina deveria ser dedicada.');

  RelReq := RelReq + #13#10 + 'Componentes incluidos neste instalador (nao e preciso internet):' + #13#10 +
       '  OpenJDK 17.0.2, WildFly 26.1.3.Final, PostgreSQL 15, aplicacao AGHUse 13.250-STABLE e base inicial.' + #13#10 +
       '  LDAP local: AD LDS, componente gratuito do proprio Windows (habilitado pelo instalador).' + #13#10;
  if ReqBloqueio <> '' then
    RelReq := RelReq + #13#10 + 'A INSTALACAO NAO PODE CONTINUAR. Requisitos nao atendidos:' + #13#10 + ReqBloqueio;
  Result := RelReq;
end;

{ ---------------------------------------------------------------- outros sistemas }

var
  OutrosTxt: String;
  OutrosQtd: Integer;

procedure Outro(const Texto: String);
begin
  OutrosTxt := OutrosTxt + '  - ' + Texto + #13#10;
  OutrosQtd := OutrosQtd + 1;
end;

function Contem(const Texto, Trecho: String): Boolean;
begin
  Result := Pos(Lowercase(Trecho), Lowercase(Texto)) > 0;
end;

{ Classifica um servico do Windows; devolve '' se nao for relevante }
function TipoServico(const Nome, Exibicao: String): String;
var T: String;
begin
  Result := '';
  T := Nome + ' ' + Exibicao;
  if (Lowercase(Nome) = '{#Servico}') or (Lowercase(Nome) = '{#Servico}-postgresql') then exit;
  if Contem(T, 'e-sus') or Contem(T, 'esus') then Result := 'sistema e-SUS (Ministerio da Saude)'
  else if Contem(T, 'postgres') then Result := 'banco de dados PostgreSQL'
  else if Contem(T, 'mysql') or Contem(T, 'mariadb') then Result := 'banco de dados MySQL/MariaDB'
  { SQL Server: so instancias (MSSQLSERVER, MSSQL$NOME); componentes auxiliares (VSS Writer, CEIP, Agent, Browser) nao sao banco }
  else if (Pos('mssql', Lowercase(Nome)) = 1) then Result := 'banco de dados SQL Server'
  else if Contem(Nome, 'oracleservice') or Contem(T, 'oracle database') then Result := 'banco de dados Oracle'
  else if Contem(T, 'firebird') or Contem(T, 'interbase') then Result := 'banco de dados Firebird'
  else if Contem(T, 'mongodb') then Result := 'banco de dados MongoDB'
  else if Lowercase(Nome) = 'w3svc' then Result := 'servidor web IIS'
  else if Contem(T, 'apache') or Contem(T, 'httpd') then Result := 'servidor web Apache'
  else if Contem(T, 'nginx') then Result := 'servidor web nginx'
  else if Contem(T, 'tomcat') then Result := 'servidor de aplicacao Tomcat'
  else if Contem(T, 'wildfly') or Contem(T, 'jboss') or Contem(T, 'glassfish') or Contem(T, 'payara') then Result := 'servidor de aplicacao Java';
end;

procedure DetectarOutrosSistemas();
var Loc, Svc, Lista, Item: Variant; i, n: Integer; Nome, Exib, Estado, Tipo: String;
begin
  OutrosTxt := ''; OutrosQtd := 0;
  try
    Loc := CreateOleObject('WbemScripting.SWbemLocator');
    Svc := Loc.ConnectServer('.', 'root\CIMV2');
    Lista := Svc.ExecQuery('SELECT Name, DisplayName, State FROM Win32_Service');
    n := Lista.Count;
    for i := 0 to n - 1 do begin
      Item := Lista.ItemIndex(i);
      Nome := Item.Name; Exib := Item.DisplayName; Estado := Item.State;
      Tipo := TipoServico(Nome, Exib);
      if Tipo <> '' then begin
        if Estado = 'Running' then Estado := 'em execucao' else Estado := 'instalado, parado';
        Outro(Tipo + ': servico "' + Exib + '" (' + Estado + ')');
      end;
    end;
  except
    Log('Nao foi possivel listar os servicos do Windows: ' + GetExceptionMessage);
  end;
  if not ServiceExists('{#Servico}') then begin
    if PortaEmUso(5432) then Outro('porta 5432 (PostgreSQL) ja esta em uso');
    if PortaEmUso(8080) then Outro('porta 8080 (usada pelo AGHUse) ja esta em uso');
    if PortaEmUso(9990) then Outro('porta 9990 (administracao do WildFly) ja esta em uso');
  end;
  if PortaEmUso(3306) then Outro('porta 3306 (MySQL/MariaDB) ja esta em uso');
  if PortaEmUso(1433) then Outro('porta 1433 (SQL Server) ja esta em uso');
  if PortaEmUso(1521) then Outro('porta 1521 (Oracle) ja esta em uso');
  if PortaEmUso(80) then Outro('porta 80 (servidor web) ja esta em uso');
  if PortaEmUso(443) then Outro('porta 443 (servidor web HTTPS) ja esta em uso');
end;

function TextoRiscos(): String;
begin
  Result :=
    'Foram encontrados outros sistemas ou servicos neste computador:' + #13#10#13#10 + OutrosTxt + #13#10 +
    'O AGHUse foi feito para um computador DEDICADO. Se voce continuar:' + #13#10 +
    '  - o AGHUse instala o seu proprio PostgreSQL (servico aghuse-postgresql) em outra porta e nao altera' + #13#10 +
    '    os bancos existentes, mas os dois sistemas passam a disputar memoria, processador e disco;' + #13#10 +
    '  - o AGHUse reserva cerca de 6,5 GB de memoria RAM so para ele: os outros sistemas podem ficar lentos' + #13#10 +
    '    ou parar por falta de memoria;' + #13#10 +
    '  - se alguma porta usada pelo AGHUse (8080, 9990) estiver ocupada, um dos sistemas pode nao iniciar;' + #13#10 +
    '  - atualizacoes, backups e reinicializacoes de um sistema passam a afetar o outro;' + #13#10 +
    '  - nao ha suporte para esta combinacao. Em servidor de producao (por exemplo, com o e-SUS ou outro' + #13#10 +
    '    sistema de saude em uso), NAO instale: use outra maquina ou uma maquina virtual.' + #13#10#13#10 +
    'Para cancelar, clique em Cancelar. Para continuar, marque a confirmacao abaixo.';
end;

{ ---------------------------------------------------------------- assistente }

function InitializeSetup(): Boolean;
var Rel: String;
begin
  Result := True;
  if Silencioso() then begin
    Rel := VerificarRequisitos(ParamOuPadrao('DIR', 'C:\AGHUse'));
    Log(Rel);
    if ReqBloqueio <> '' then begin
      Log('Requisitos minimos nao atendidos - instalacao cancelada.');
      Result := False;
      exit;
    end;
    DetectarOutrosSistemas();
    if OutrosQtd > 0 then begin
      Log(TextoRiscos());
      if ParamOuPadrao('ACEITO_RISCO', 'nao') <> 'sim' then begin
        Log('Outros sistemas encontrados e /ACEITO_RISCO=sim nao informado - instalacao cancelada.');
        Result := False;
      end else
        AceiteRegistro := 'aceito no modo silencioso (/ACEITO_RISCO=sim)';
    end;
  end;
end;

procedure AceiteClick(Sender: TObject);
begin
  WizardForm.NextButton.Enabled := AceiteCheck.Checked;
end;

procedure InitializeWizard();
begin
  LoginPage := CreateInputOptionPage(wpLicense, 'Autenticacao (login)',
    'Como os usuarios vao entrar no AGHUse?',
    'O AGHUse nao guarda senhas: elas sao conferidas em um diretorio LDAP (como no uso real do sistema) ' +
    'ou, no modo de avaliacao, pelo banco de dados. Nos dois casos nao ha nada a preencher.',
    True, False);
  LoginPage.Add('LDAP local neste computador (RECOMENDADO)');
  LoginPage.Add('Banco de dados, sem diretorio (avaliacao rapida)');
  if Lowercase(ParamOuPadrao('MODO', 'ldap-local')) = 'banco' then LoginPage.SelectedValueIndex := 1
  else LoginPage.SelectedValueIndex := 0;

  ReqPage := CreateOutputMsgMemoPage(LoginPage.ID, 'Verificacao dos requisitos',
    'Conferindo se este computador tem o minimo necessario para o AGHUse.',
    'Resultado da verificacao:', '');

  AceitePage := CreateCustomPage(ReqPage.ID, 'Outros sistemas neste computador',
    'Leia com atencao: este computador nao parece ser dedicado ao AGHUse.');
  AceiteMemo := TNewMemo.Create(AceitePage);
  AceiteMemo.Parent := AceitePage.Surface;
  AceiteMemo.Left := 0; AceiteMemo.Top := 0;
  AceiteMemo.Width := AceitePage.SurfaceWidth;
  AceiteMemo.Height := AceitePage.SurfaceHeight - ScaleY(44);
  AceiteMemo.ReadOnly := True;
  AceiteMemo.ScrollBars := ssVertical;
  AceiteMemo.WordWrap := True;
  AceiteCheck := TNewCheckBox.Create(AceitePage);
  AceiteCheck.Parent := AceitePage.Surface;
  AceiteCheck.Left := 0;
  AceiteCheck.Top := AceiteMemo.Top + AceiteMemo.Height + ScaleY(8);
  AceiteCheck.Width := AceitePage.SurfaceWidth;
  AceiteCheck.Height := ScaleY(20);
  AceiteCheck.Caption := 'Li, estou ciente de que os sistemas acima podem ser afetados e assumo o risco.';
  AceiteCheck.OnClick := @AceiteClick;

end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if PageID = LoginPage.ID then
    Result := (Lowercase(ParamOuPadrao('MODO', '')) = 'ldap-externo');
  if PageID = AceitePage.ID then begin
    DetectarOutrosSistemas();
    Result := (OutrosQtd = 0);
  end;
end;

{ Senha do administrador gravada pelo motor no arquivo de credenciais }
function LerSenhaAdmin(const Arquivo: String): String;
var Linhas: TArrayOfString; i, p: Integer; L: String;
begin
  Result := '';
  if not LoadStringsFromFile(Arquivo, Linhas) then exit;
  for i := 0 to GetArrayLength(Linhas) - 1 do begin
    L := Linhas[i];
    if Pos('Senha do administrador', L) = 1 then begin
      p := Pos(': ', L);
      if p > 0 then Result := Trim(Copy(L, p + 2, Length(L)));
      exit;
    end;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
var Rotulo: String;
begin
  if CurPageID = ReqPage.ID then begin
    ReqPage.RichEditViewer.Lines.Text := VerificarRequisitos(WizardDirValue());
    if ReqBloqueio <> '' then WizardForm.NextButton.Enabled := False;
  end;
  if CurPageID = AceitePage.ID then begin
    AceiteMemo.Text := TextoRiscos();
    WizardForm.NextButton.Enabled := AceiteCheck.Checked;
  end;
  if CurPageID = wpFinished then begin
    if Sucesso then begin
      if SenhaAdmin <> '' then Rotulo := 'Senha:  ' + SenhaAdmin + #13#10
      else Rotulo := 'Senha:  a do diretorio (LDAP/AD da instituicao)' + #13#10;
      WizardForm.FinishedLabel.Caption :=
        'O AGHUse foi instalado com sucesso e esta funcionando.' + #13#10 +
#ifdef VarianteNome
        '{#VarianteNome} (o que mudou: ferramentas\modificacoes\integracao-ldap\README.md)' + #13#10 +
#endif
        '' + #13#10 +
        'Neste computador:  ' + UrlLoc + #13#10 +
        'Outros computadores:  ' + Url + #13#10 +
        'Usuario:  ' + AdminLogin() + #13#10 + Rotulo + #13#10 +
        'Esta senha e as demais credenciais ficaram gravadas em:' + #13#10 +
        Cred + #13#10 +
        '(o arquivo sera aberto ao concluir; acesso somente para Administradores)' + #13#10#13#10 +
        'Use o icone AGHUse na Area de Trabalho ou no menu Iniciar.' + #13#10 +
        'Para cadastrar usuarios: menu Iniciar > AGHUse > Como cadastrar usuarios.' + #13#10 +
        'Ambiente de TESTE: para producao, baixe o projeto e ajuste o aghuse.conf.';
    end
    else if Executou then
      WizardForm.FinishedLabel.Caption :=
        'A INSTALACAO FALHOU na etapa: ' + EtapaAtual + #13#10#13#10 + UltimoErro + #13#10#13#10 +
        'O log completo esta em ' + ExpandConstant('{commonappdata}\AGHUse\logs\aghuse-instalador-{#Servico}.log') + '.' + #13#10 +
        'Corrija o problema e execute este instalador novamente: os dados ja criados sao preservados.';
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = ReqPage.ID then
    Result := (ReqBloqueio = '');
  if CurPageID = AceitePage.ID then begin
    Result := AceiteCheck.Checked;
    if Result then
      AceiteRegistro := 'aceito por ' + GetUserNameString + ' em ' + GetDateTimeString('dd/mm/yyyy hh:nn', '/', ':');
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var S, M: String;
begin
  if ModoLogin() = 'ldap-local' then M := 'LDAP local neste computador (AD LDS, base DC=aghuse,DC=local)'
  else if ModoLogin() = 'banco' then M := 'banco de dados (avaliacao)'
  else M := 'LDAP/AD da instituicao (parametros do aghuse.conf)';
  S := 'Configuracao PRE-DEFINIDA para teste (nada a preencher):' + NewLine + NewLine;
  S := S + 'Pasta:' + NewLine + Space + WizardDirValue() + NewLine + NewLine;
  S := S + 'Login:' + NewLine + Space + M + NewLine;
  S := S + Space + 'administrador ' + AdminLogin() + ' (senha gerada e mostrada ao final)' + NewLine + NewLine;
  S := S + 'Acesso:' + NewLine + Space + Format('http://localhost:%d/aghu  (porta %d liberada no firewall)', [PortaHttp(), PortaHttp()]) + NewLine + NewLine;
  if ServiceExists('{#Servico}') then begin
    S := S + 'Reinstalacao:' + NewLine + Space;
    if ParamOuPadrao('RECRIAR', 'nao') = 'sim' then S := S + 'o banco sera APAGADO e recriado' else S := S + 'os dados cadastrados serao mantidos';
    S := S + NewLine + NewLine;
  end;
  S := S + 'Servicos do Windows: aghuse, aghuse-postgresql';
  if ModoLogin() = 'ldap-local' then S := S + ' e ADAM_aghuseldap (LDAP)';
  S := S + NewLine + NewLine + 'A instalacao leva de 15 a 45 minutos. Nao desligue o computador.' + NewLine + NewLine;
  S := S + 'Para producao ou outra configuracao: baixe o projeto, ajuste o aghuse.conf e execute instalar.bat (recomendado).';
  Result := S;
end;
{ ---------------------------------------------------------------- instalacao }

procedure RodarOculto(const Exe, Params: String);
var rc: Integer;
begin
  Exec(Exe, Params, '', SW_HIDE, ewWaitUntilTerminated, rc);
end;

{ Reinstalacao: libera os arquivos do Java e do PostgreSQL antes de sobrescrever }
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if ServiceExists('{#Servico}') then begin
    WizardForm.StatusLabel.Caption := 'Parando o servico do AGHUse...';
    RodarOculto(ExpandConstant('{sys}\sc.exe'), 'stop {#Servico}');
    RodarOculto(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -Command "$s=''{#Servico}''; for($i=0;$i -lt 90 -and (Get-Service $s).Status -ne ''Stopped'';$i++){Start-Sleep 2}; ' +
      'Get-CimInstance Win32_Process -Filter \"Name=''java.exe''\" | ? { $_.CommandLine -like ''*' + WizardDirValue() + '*'' } | % { Stop-Process -Id $_.ProcessId -Force }"');
  end;
  if ServiceExists('{#Servico}-postgresql') then begin
    RodarOculto(ExpandConstant('{sys}\sc.exe'), 'stop {#Servico}-postgresql');
    Sleep(4000);
  end;
end;

procedure LinhaMotor(const S: String; const Error, FirstLine: Boolean);
var T: String;
begin
  T := Trim(S);
  if T = '' then exit;
  if Length(Saida) < 200000 then Saida := Saida + T + #13#10;
  if Copy(T, 1, 4) = '==> ' then begin
    EtapaAtual := Copy(T, 5, Length(T));
    WizardForm.StatusLabel.Caption := EtapaAtual;
  end else if Pos('RESULTADO_URL=', T) = 1 then Url := Copy(T, 15, Length(T))
  else if Pos('RESULTADO_URL_LOCAL=', T) = 1 then UrlLoc := Copy(T, 21, Length(T))
  else if Pos('RESULTADO_CRED=', T) = 1 then Cred := Copy(T, 16, Length(T))
  else begin
    if Pos('ERRO:', T) = 1 then UltimoErro := T;
    WizardForm.FilenameLabel.Caption := T;
  end;
  Log('motor: ' + T);
end;

var ConfTxt: String;

procedure Par(const Nome, Valor: String);
begin
  ConfTxt := ConfTxt + Nome + '="' + Valor + '"' + #13#10;
end;

procedure GravarConf();
var Ferr, Lista: String;
begin
  Ferr := ExpandConstant('{app}\ferramentas');
  Lista := Trim(OutrosTxt);
  StringChangeEx(Lista, #13#10, #13#10 + '#   ', True);
  ConfTxt := '# AGHUse - configuracao PRE-DEFINIDA de teste, gravada pelo instalador grafico em ' + GetDateTimeString('dd/mm/yyyy hh:nn', '/', ':') + #13#10 +
       '# Para outra configuracao (producao, LDAP/AD da instituicao, outra porta): use o aghuse.conf' + #13#10 +
       '# completo do projeto, ajuste e execute instalar.bat como Administrador.' + #13#10;
  if AceiteRegistro <> '' then begin
    ConfTxt := ConfTxt + '# ACEITE DE RISCO: outros sistemas encontrados neste computador - ' + AceiteRegistro + #13#10;
    ConfTxt := ConfTxt + '#   ' + Lista + #13#10;
  end;
  Par('AMBIENTE', 'teste'); Par('CONFIRMO_PRODUCAO', 'nao'); Par('NOME_AMBIENTE', 'AGHUSE-TESTE');
  Par('MODO_LOGIN', ModoLogin());
  Par('ADMIN_LOGIN', AdminLogin());
  Par('ADMIN_SENHA', '');
  Par('LDAP_LOCAL_PORTA', '50389');
  if ModoLogin() = 'ldap-externo' then begin
    Par('LDAP_HOST', ParamOuPadrao('LDAP_HOST', '')); Par('LDAP_PORTA', ParamOuPadrao('LDAP_PORTA', '389'));
    Par('LDAP_USER_DN', ParamOuPadrao('LDAP_USER_DN', '')); Par('LDAP_BASE_USUARIOS', ParamOuPadrao('LDAP_BASE', ''));
    Par('LDAP_ATRIBUTO_LOGIN', ParamOuPadrao('LDAP_ATRIBUTO', 'sAMAccountName'));
    Par('LDAP_FILTRO', ParamOuPadrao('LDAP_FILTRO', '(&(objectClass=user)(sAMAccountName=%s))'));
    Par('LDAP_BIND_DN', ParamOuPadrao('LDAP_BIND_DN', '')); Par('LDAP_BIND_SENHA', ParamOuPadrao('LDAP_BIND_SENHA', ''));
  end;
  Par('PREFIXO', RemoveBackslash(ExpandConstant('{app}')));
  Par('SERVICO', '{#Servico}');
  Par('CONTA_SERVICO', 'LocalService');
  if ParamOuPadrao('PROXY', 'nao') = 'sim' then begin Par('HTTP_BIND', '127.0.0.1'); Par('PROXY_REVERSO', 'sim'); end
  else begin Par('HTTP_BIND', '0.0.0.0'); Par('PROXY_REVERSO', 'nao'); end;
  Par('PORT_OFFSET', IntToStr(PortaHttp() - 8080));
  Par('MEMORIA_JVM', Uppercase(ParamOuPadrao('MEMORIA', '')));
  Par('LIBERAR_FIREWALL', ParamOuPadrao('FIREWALL', 'sim'));
  Par('RECRIAR_BANCO', ParamOuPadrao('RECRIAR', 'nao'));
  SaveStringToFile(Ferr + '\aghuse.conf', ConfTxt, False);
end;

procedure ExecutarMotor();
var rc: Integer; Ferr, Params: String;
begin
  Ferr := ExpandConstant('{app}\ferramentas');
  GravarConf();
  Executou := True;
  Sucesso := False;
  EtapaAtual := 'inicio';
  WizardForm.StatusLabel.Caption := 'Configurando o AGHUse (Java, PostgreSQL, base inicial, WildFly e servicos)...';
  WizardForm.FilenameLabel.Caption := '';
  WizardForm.ProgressGauge.Style := npbstMarquee;
  Params := '-NoProfile -ExecutionPolicy Bypass -File "' + Ferr + '\instalar.ps1" -Conf "' + Ferr + '\aghuse.conf" -Pacote "' + Ferr + '" -NaoInterativo';
  if ExecAndLogOutput(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Params, Ferr,
                      SW_HIDE, ewWaitUntilTerminated, rc, @LinhaMotor) then
    Sucesso := (rc = 0) and (Url <> '')
  else
    UltimoErro := 'Nao foi possivel executar o PowerShell: ' + SysErrorMessage(rc);
  WizardForm.ProgressGauge.Style := npbstNormal;
  if Sucesso then
    begin
    if UrlLoc = '' then UrlLoc := Url;
    SenhaAdmin := LerSenhaAdmin(Cred);
    SaveStringToFile(ExpandConstant('{app}\Acessar o AGHUse.url'), '[InternetShortcut]' + #13#10 + 'URL=' + UrlLoc + #13#10 +
      'IconFile=' + ExpandConstant('{app}\aghuse.ico') + #13#10 + 'IconIndex=0' + #13#10, False);
  end
  else begin
    if UltimoErro = '' then UltimoErro := 'O motor de instalacao terminou com erro (codigo ' + IntToStr(rc) + ').';
    if not Silencioso() then
      MsgBox('A instalacao falhou na etapa "' + EtapaAtual + '":' + #13#10#13#10 + UltimoErro + #13#10#13#10 +
             'Veja o log em ' + ExpandConstant('{commonappdata}\AGHUse\logs\aghuse-instalador-{#Servico}.log'), mbError, MB_OK);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then ExecutarMotor();
end;

function InstalouOk(): Boolean;
begin
  Result := Sucesso;
end;

function InstalouFalhou(): Boolean;
begin
  Result := Executou and not Sucesso;
end;

function UrlFinal(Param: String): String;
begin
  Result := Url;
end;

function UrlLocal(Param: String): String;
begin
  if UrlLoc <> '' then Result := UrlLoc else Result := Url;
end;

function CredFinal(Param: String): String;
begin
  Result := Cred;
end;

{ Codigo de saida 1 quando o motor falha: sem isto o setup terminava com 0 (os arquivos foram
  copiados), e quem automatiza (start /wait ... & echo %ERRORLEVEL%) nao percebia a falha }
function GetCustomSetupExitCode(): Integer;
begin
  if Executou and not Sucesso then Result := 1 else Result := 0;
end;

procedure DeinitializeSetup();
begin
  if Executou and not Sucesso then
    Log('ERRO: instalacao do AGHUse falhou: ' + UltimoErro);
end;

{ ---------------------------------------------------------------- desinstalacao }

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var rc: Integer; Ferr, Extra: String;
begin
  if CurUninstallStep = usUninstall then begin
    Ferr := ExpandConstant('{app}\ferramentas');
    { Pergunta afirmativa: "Sim" = apagar tudo. Botao padrao "Nao" (mantem os dados), tambem no modo
      silencioso, para nao apagar dados por engano. }
    Extra := ' -ManterBanco';
    if SuppressibleMsgBox('Deseja APAGAR tambem todos os dados e configuracoes do AGHUse?' + #13#10#13#10 +
         'Sim: apaga TUDO - banco de dados (pacientes e cadastros), contas de acesso do LDAP local,' + #13#10 +
         '     senhas, credenciais e logs. Nao ha como desfazer.' + #13#10 +
         'Nao: remove so o programa e mantem o banco (servico aghuse-postgresql) e o LDAP local' + #13#10 +
         '     (servico ADAM_aghuseldap), para reinstalar depois sem perder os dados.',
         mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES then
      Extra := '';
    if FileExists(Ferr + '\desinstalar.ps1') then
      Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
           '-NoProfile -ExecutionPolicy Bypass -File "' + Ferr + '\desinstalar.ps1" -Sim' + Extra + ' -Conf "' + Ferr + '\aghuse.conf"',
           Ferr, SW_HIDE, ewWaitUntilTerminated, rc);
  end;
end;
