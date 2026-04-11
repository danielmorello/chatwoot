@echo off
REM Build da imagem Docker para producao (GS2 Next Connecta).
REM Uso: scripts\build-docker-image.bat [IMAGE_NAME] [IMAGE_TAG]
REM Exemplo: scripts\build-docker-image.bat
REM Exemplo: scripts\build-docker-image.bat meu-registry/gs2-next-connecta v1.0.0

set IMAGE_NAME=%~1
set IMAGE_TAG=%~2
if "%IMAGE_NAME%"=="" set IMAGE_NAME=gs2-next-connecta
if "%IMAGE_TAG%"=="" set IMAGE_TAG=latest

echo Building Docker image: %IMAGE_NAME%:%IMAGE_TAG%
echo.

cd /d "%~dp0.."
docker build -t %IMAGE_NAME%:%IMAGE_TAG% -f ./docker/Dockerfile .

echo.
echo Done. Image: %IMAGE_NAME%:%IMAGE_TAG%
