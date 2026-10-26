@echo off

REM This is a Windows Batch script to install a private pyRevit extension
REM Docs found here https://pyrevitlabs.notion.site/Manage-pyRevit-extensions-fa853768e94240b5b59803e5d7171be3

REM Define variables
set command_name=extend
set extension_type=ui
set extension_name=Unispace
set repository_url=https://github.com/UnispaceIT/toolbar.git
set branch=main

REM Build the command
set pyrevit_command=pyrevit %command_name% %extension_type% %extension_name% "%repository_url%" --branch="%branch%"

REM Print the command to the console
echo Running command: %pyrevit_command%

REM Install the pyrevit extension
%pyrevit_command%

REM Command to enable the extension
set enable_command=pyrevit extensions enable %extension_name%

REM Print the command to the console for enabling the extension
echo Running command to enable extension: %enable_command%

REM Run the command to enable the extension
%enable_command%

REM End of the script
