@echo off
setlocal
set "NOPAUSE=%~1"
echo ===============================================
echo  Gerador de pacote - Launcher HEXAGONAL (8083)
echo  (empacota o launcher-bootstrap; JDK 21 embutido)
echo ===============================================
set "HERE=%~dp0"
set "ROOT=%HERE%.."
set "BOOT=%ROOT%\launcher-bootstrap"
set "DIST=%HERE%dist"
set "TGZ=%HERE%launcher.tar.gz"
rem -- reusa o JRE ja baixado (cache do pipeline legado, agora em legacy/) --
set "JDKCACHE=%ROOT%\legacy\launcher-test\jdk-cache"
set "JRETGZ=%JDKCACHE%\temurin-jre-21-linux-x64.tar.gz"
set "JRE_URL=https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse?project=jdk"
set "TAR=%WINDIR%\System32\tar.exe"

echo.
echo [1/5] Compilando o reator (mvn -DskipTests clean package)...
call mvn -q -f "%ROOT%\pom.xml" -DskipTests clean package
if errorlevel 1 goto :erro

set "JAR="
for %%f in ("%BOOT%\target\launcher*.jar") do set "JAR=%%~ff"
if not defined JAR goto :nojar

echo [2/5] Obtendo JDK 21 Linux x64 (so na primeira vez)...
if not exist "%JDKCACHE%" mkdir "%JDKCACHE%"
if exist "%JRETGZ%" (
  echo     ja em cache.
) else (
  powershell -NoProfile -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%JRE_URL%' -OutFile '%JRETGZ%'"
  if errorlevel 1 goto :erro_jdk
)

echo [3/5] Montando pasta dist (jar + config + scripts + kong + JDK)...
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%"
copy /y "%JAR%" "%DIST%\" >nul
copy /y "%BOOT%\src\main\resources\application.yml" "%DIST%\" >nul
copy /y "%HERE%payload\*" "%DIST%\" >nul
xcopy /e /i /y "%HERE%kong" "%DIST%\kong" >nul
copy /y "%JRETGZ%" "%DIST%\jdk-runtime.tar.gz" >nul

echo [4/5] Gerando pacote .tar.gz...
if exist "%TGZ%" del /q "%TGZ%"
pushd "%DIST%"
"%TAR%" -czf "%TGZ%" .
if errorlevel 1 ( popd & goto :erro )
popd

echo [5/5] OK.
echo.
echo ====== PRONTO ======
echo  Pasta da app:  %DIST%
echo  Pacote:        %TGZ%
echo  (reator hexagonal na porta 8083; kong.yml incluido)
echo.
if /i not "%NOPAUSE%"=="nopause" pause
endlocal & exit /b 0

:erro
echo. & echo *** ERRO ao gerar o pacote. Veja acima. ***
if /i not "%NOPAUSE%"=="nopause" pause
endlocal & exit /b 1
:nojar
echo. & echo *** ERRO: jar nao encontrado em "%BOOT%\target". ***
if /i not "%NOPAUSE%"=="nopause" pause
endlocal & exit /b 1
:erro_jdk
echo. & echo *** ERRO ao baixar o JDK 21. Baixe manual e salve como %JRETGZ% ***
if /i not "%NOPAUSE%"=="nopause" pause
endlocal & exit /b 1
