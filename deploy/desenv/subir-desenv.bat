@echo off
REM ==========================================================================
REM  Sobe TODOS os servicos SCCI na desenv com 1 clique (Windows).
REM  Requer OpenSSH (ja vem no Windows 10/11).  Duplo-clique ou:  subir-desenv.bat
REM  Edite HOST/USER/PORT/KEY abaixo se mudar de ambiente.
REM ==========================================================================
setlocal
set HOST=10.3.98.108
set USUARIO=jaime.vicente
set PORTA=23
set KEY=%USERPROFILE%\.ssh\id_rsa

echo.
echo === Subindo os servicos SCCI na desenv (%HOST%) ===
echo.
echo -^> enviando o script para ~/subir-desenv.sh ...
scp -P %PORTA% -i "%KEY%" "%~dp0subir-remoto.sh" %USUARIO%@%HOST%:subir-desenv.sh
if errorlevel 1 goto :erro

echo -^> executando na box ...
ssh -p %PORTA% -i "%KEY%" %USUARIO%@%HOST% "sed -i 's/\r//g' subir-desenv.sh; bash subir-desenv.sh"
if errorlevel 1 goto :erro

echo.
echo Pronto. Abra:  http://%HOST%:8095
goto :fim

:erro
echo.
echo FALHOU (SSH/rede^). Confira a VPN/rede e a chave em %KEY%.

:fim
echo.
pause
endlocal
