@echo off
setlocal
echo ===============================================
echo  Enviar pacote - Launcher HEXAGONAL (SSH, 8083)
echo ===============================================
set "HERE=%~dp0"
set "CONF=%HERE%deploy.conf"
set "TGZ=%HERE%launcher.tar.gz"
set "INSTALL=%HERE%instalar.sh"

if not exist "%CONF%" ( echo ERRO: deploy.conf nao encontrado. & pause & exit /b 1 )
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%CONF%") do set "%%a=%%b"

if "%HOST%"=="" goto :semconf
if "%USUARIO%"=="" goto :semconf
if "%DESTINO%"=="" goto :semconf
if "%PORTA%"=="" set "PORTA=8083"
if "%SSHPORT%"=="" set "SSHPORT=22"
if "%KONG_RELOAD%"=="" set "KONG_RELOAD=false"
if "%KONG_MODE%"=="" set "KONG_MODE=reload"
set "SSHOPT="
if not "%SSHKEY%"=="" set SSHOPT=-i "%SSHKEY%"

echo.
echo [1/4] Gerando o pacote...
call "%HERE%gerar-pacote.bat" nopause
if errorlevel 1 ( echo ERRO no build. & pause & exit /b 1 )
if not exist "%TGZ%" ( echo ERRO: pacote nao gerado. & pause & exit /b 1 )

echo [2/4] Preparando pasta: %USUARIO%@%HOST%:%DESTINO%
ssh -p %SSHPORT% %SSHOPT% %USUARIO%@%HOST% "mkdir -p '%DESTINO%'"
if errorlevel 1 ( echo ERRO no SSH. & pause & exit /b 1 )

echo [3/4] Enviando pacote e instalador...
scp -P %SSHPORT% %SSHOPT% "%TGZ%" %USUARIO%@%HOST%:"%DESTINO%/"
if errorlevel 1 ( echo ERRO no scp do pacote. & pause & exit /b 1 )
scp -P %SSHPORT% %SSHOPT% "%INSTALL%" %USUARIO%@%HOST%:"%DESTINO%/"
if errorlevel 1 ( echo ERRO no scp do instalador. & pause & exit /b 1 )

echo [4/4] Instalando e subindo (porta %PORTA%; kong_reload=%KONG_RELOAD%)...
ssh -p %SSHPORT% %SSHOPT% %USUARIO%@%HOST% "cd '%DESTINO%' && bash instalar.sh %PORTA% %KONG_RELOAD% %KONG_MODE%"

echo.
echo ====== CONCLUIDO ======
echo  Servidor:  %USUARIO%@%HOST%   (reator na %PORTA%, Kong escuta na 8082)
echo  Health:    http://%HOST%:%PORTA%/actuator/health
echo  Parar:     ssh %USUARIO%@%HOST% "fuser -k %PORTA%/tcp"
echo.
pause
endlocal
goto :eof

:semconf
echo. & echo *** Preencha HOST, USUARIO, DESTINO no deploy.conf. ***
pause
endlocal
