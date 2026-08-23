@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\dev-stack\dev-stack.ps1" %*
