@rem ***
@rem *** OCaml Installation Scripts
@rem ***
@rem Copyright (c) 2011-2015 MetaStack Solutions Ltd.
@rem Released under the Creative Commons Attribution 4.0 International (CC BY 4.0) Licence
@rem See http://creativecommons.org/licenses/by/4.0/
@rem This licence applies to all patches in the Source directory
@rem 28-Jul-2011 @ DRA
@rem Substantially revised 16-Jan-2012
@rem Upgraded for OCaml 4.00.1 19-Jun-2013
@rem Upgraded for OCaml 4.01.0 15-Mar-2014
@rem Revised for demonstrations 13-Sep-2015
@setlocal
@echo off
@rem This script is self-documenting -- build --docs to view
@rem
@rem ***
@rem *** Anti-Virus
@rem ***
@rem Sophos should be completely disabled during installation (certainly the Sophos Anti-Virus service should be stopped and possibly the Sophos Web
@rem Intelligence Service). When enabled (certainly on DIVA), it was rare that OCaml itself would complete compilation without a random error. fork
@rem errors were also seen in some packages when compiling on TENOR in the same way.

set SED_C=%~dps0Support\sed.exe
set UNIQ_C=%~dps0Support\uniq.exe
set LESS_C=%~dps0Support\less.exe
set GREP_C=%~dps0Support\grep.exe
set DIRNAME_C=%~dps0Support\dirname.exe
set SORT_C=%~dps0Support\sort.exe
set TR_C=%~dps0Support\tr.exe
set PRINTF_C=%~dps0Support\printf.exe

@rem Load the configuration
call %~dps0build-config.cmd

if "%1" equ "/path" goto Path
if "%1" equ "--docs" goto Docs

@rem Must be run elevated
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 goto Elevate

if "%1" equ "--make-root" goto MakeRoot

@rem ***
@rem *** Environment
@rem ***
@rem
@rem Prerequisites:
@rem 1. Create C:\Dev with SYSTEM & Administrators: Full Control; Users: Read (run build --make-root). This step can be omitted if ActiveTcl is not
@rem    installed under C:\Dev
@rem 2. Install relevant ActiveTcl distribution
@rem      Install for all users
@rem      Don't enable the 'Add ".tcl" to your executable path extensions' or 'Associate ".tcl" extension to ActiveTcl 8.6' options
@rem      Normal installation is to %ROOT%\Tcl but as long as tk86.dll is in PATH then it will work
@rem      Program group not required
@rem      LIB must include ActiveTcl's lib directory (needs to be done manually)
@rem      PATH must include ActiveTcl's bin directory (done by ActiveTcl setup)
@rem 3. Configure environment for OCaml and Cygwin
@rem      CYGWIN must include winsymlinks:native and nodosfilewarning
@rem        (suppresses various warnings and ensures that any stray ln calls create .lnk files instead of Cygwin unicode links)
@rem      PATH must include C:\Dev\OCaml\bin
@rem      PATH must include C:\cygwin\dll
@rem      OCAMLLIB must be set to C:\Dev\OCaml\lib
@rem Cygwin is configured so that its bin directory does not need to be included in the PATH. Great problems seem to arise if cygwin1.dll is not
@rem somewhere inside the Cygwin directory, hence the creation of the dll subdirectory to house it. Similarly, if libgcc_s_sjlj-1.dll is symlinked
@rem outside C:\cygwin, then access denied errors seem to occur when loading DLLs which depend on it.

@rem Check which port we're building (currently only mingw32 is supported)
if "%1" equ "--build=mingw32" (
  set FLAVOUR=
  set MACHINE=i686-w64-mingw32
) else (
  if "%1" equ "" (
    set FLAVOUR=
    set MACHINE=i686-w64-mingw32
  ) else (
    echo Unrecognised command line
    pause
    goto :EOF
  )
)

set OCAMLROOT=%ROOT%\OCaml%FLAVOUR%

@rem Create the root, if necessary
call :MakeRoot

@rem Create the OCaml bin directory, if necessary
if not exist %OCAMLROOT%\bin mkdir %OCAMLROOT%\bin

@rem Check the environment (see documentation above)

@rem PATH must include OCaml bin directory
set FAULT=1
for /f "delims=" %%F in ('"%0" /path') do if /i "%%F" equ "%OCAMLROOT%\bin" set FAULT=0
if %FAULT% equ 1 echo PATH must include %OCAMLROOT%\bin

set FTEST=1
for /f "delims=" %%F in ('"%0" /path') do if /i "%%F" equ "%CYGROOT%\dll" set FTEST=0
if %FTEST% equ 1 (
  echo PATH must include %CYGROOT%\dll
  set FAULT=1
)

@rem CYGWIN must include winsymlinks:native and nodosfilewarning
set FLAGS=2
for /f %%F in ('echo %CYGWIN%^| %SED_C% -e "s/ /\r\n/g" ^| sort ^| %UNIQ_C%') do (
  if %%F equ winsymlinks:native (
    set /a FLAGS-=1
  ) else if %%F equ nodosfilewarning (
    set /a FLAGS-=1
  )
)
if %FLAGS% gtr 0 (
  set FAULT=1
  echo CYGWIN must include the winsymlinks:native and nodosfilewarning options
)

@rem OCAMLLIB must be set
if /i "%OCAMLLIB%" neq "%OCAMLROOT%\lib" (
  echo OCAMLLIB should be set to %OCAMLROOT%\lib
  set FAULT=1
)

@rem LIB must include ActiveTcl's lib directory
for %%F in (tk86.lib) do (
  if "%%~$LIB:F" equ "" (
    echo LIB should include ActiveTCL's lib directory ^(could not find find tk86.lib^)
    set FAULT=1
  )
)

@rem PATH must include ActiveTcl's bin directory
@rem We also set TCLROOT here
for %%F in (tk86.dll) do (
  if "%%~$PATH:F" equ "" (
    echo PATH should include ActiveTCL's bin directory ^(could not find tk86.dll^)
    set FAULT=1
  ) else (
    for /f %%G in ('%DIRNAME_C% %%~$PATH:F') do for /f %%H in ('%DIRNAME_C% %%G') do set TCLROOT=%%H
  )
)

@rem If any errors occurred, pause and abort
if %FAULT% equ 1 (
  pause
  goto :EOF
)

@rem ***
@rem *** Build Tree
@rem ***
@rem All files except build.cmd from Source are copied to C:\Dev\Src
@rem
if exist %ROOT%\Src (
  echo %ROOT%\Src is non-empty -- all files will be deleted. Press CTRL+C to abort this script
  pause
  rd /s /q %ROOT%\Src
)
md %ROOT%\Src
copy %~dps0Source\* %ROOT%\Src > nul
mkdir %ROOT%\Src\build
%GREP_C% "^=" %~fs0 | %SED_C% -e "s/^=//" > %ROOT%\Src\build\build
%GREP_C% "^\(\*\|Package \)" %~fs0 | %SED_C% -e "s/^*//" | %SED_C% -e "s/^Package \([^ ]*\).*/;;\n  \1)/" > %ROOT%\Src\build\build-package
%GREP_C% "^Package " %~fs0 | %SED_C% -e "s/{[^}]*}//" -e "s/Package \([^ ]*\)\( \[\)\?\([^]]*\)\]\?/\1 \3/" -e "s/ *$//" > %ROOT%\Src\build\packages

@rem ***
@rem *** Cygwin
@rem ***
@rem Cygwin is installed for all users (with no desktop shortcut) to C:\cygwin with the following packages:
@rem   + git subversion mercurial openssh (Repository access)
@rem   + make patch (general build system)
@rem   + ruby (MooTools build system)
@rem   + m4 (Needed by findlib's configure scripts)
@rem   + mingw64-i686-gcc-g++ (SpiderMonkey needs a C++ compiler - if no C++ compiler is required, mingw64-i686-gcc-core can be installed instead)
@rem   + unzip (FlexDLL bootstrapping)
@rem   + ncurses (for the clear command - build system)
@rem   + procmail (for the lockfile command - build system)
@rem Alter /etc/fstab to mount /cygdrive with the noacl option (means that files created outside C:\cygwin will get default NTFS permissions, instead
@rem of forced Cygwin permissions)
@rem Alter /etc/profile and below the comment block "Here is how HOME is set" add
@rem   unset HOME
@rem   HOME=`fgrep $USER /etc/passwd | sed -e "s/.*:\([^:]*\):[^:]*$/\1/"`
@rem   export HOME
@rem Create a link to C:\cygwin\bin\cygwin1.dll in C:\cygwin\dll
@rem Create a link to C:\cygwin\usr\i686-w64-mingw32\sys-root\mingw\bin\libgcc_s_sjlj-1.dll in C:\cygwin\dll
if not exist %CYGROOT%\bin\cygwin1.dll (
  echo Installing Cygwin...
  for /f "delims=" %%D in ('dir %CYGREPO%\setup*x86.exe /a-d /b') do "%CYGREPO%\%%D" --root=%CYGROOT% --local-install --local-package-dir=%CYGREPO% --quiet-mode --no-desktop --packages=git,mercurial,openssh,make,mingw64-i686-gcc-g++,subversion,m4,ruby,patch,unzip,ncurses,procmail >nul 2>&1
  %SED_C% -i -e "s/\(.* cygdrive\) /\1 noacl,/" %CYGROOT%\etc\fstab
  %SED_C% -i -e "s/# If the home directory doesn't exist, create it\./unset HOME\nHOME=`mkpasswd | fgrep $USER | sed -e 's\/.*:\\([^:]*\\):[^:]*$\/\\1\/'`\nexport HOME/" %CYGROOT%\etc\profile
)
if not exist %CYGROOT%\dll mkdir %CYGROOT%\dll
if not exist %CYGROOT%\dll\cygwin1.dll mklink %CYGROOT%\dll\cygwin1.dll %CYGROOT%\bin\cygwin1.dll
if not exist %CYGROOT%\dll\libgcc_s_sjlj-1.dll mklink %CYGROOT%\dll\libgcc_s_sjlj-1.dll %CYGROOT%\usr\i686-w64-mingw32\sys-root\mingw\bin\libgcc_s_sjlj-1.dll

echo We now transfer control to Cygwin

@rem This command stops Sophos AntiVirus if it's both installed and running
set SAV_START=0
(sc query SAVService | %GREP_C% -q "STATE.*RUNNING") && sc stop SAVService && set SAV_START=1

setlocal
set SED_C=
set UNIQ_C=
set LESS_C=
set GREP_C=
set DIRNAME_C=
set SORT_C=
set TR_C=

echo %TIME%
%CYGROOT%\bin\bash.exe --login %ROOT%\Src\build\build
endlocal

pushd %ROOT%\Src

cd docs
mkdir userlib
cd userlib

setlocal enabledelayedexpansion

for /f "tokens=1-3" %%L in (%~fs0) do (
  if "%%L" equ "Package" set PACKAGE=%%M
  if "%%L" equ "Docs" (
    for /f %%A in ('echo !PACKAGE!^| %TR_C% [A-Z] [a-z]') do set TARGET=%%A
    if "%%N" neq "" set TARGET=!TARGET!\%%N
    mkdir !TARGET!
    for /f %%A in ('echo %%M^| %SED_C% -e "s/\//\\/g"') do set SOURCE=%%A
    %PRINTF_C% "Assembling docs for !PACKAGE!... "
    xcopy /e ..\..\!SOURCE! !TARGET!\ | %GREP_C% "copied$"
  )
  if "%%L" equ "DocsRemove" if exist !TARGET!\%%M del !TARGET!\%%M

)

%PRINTF_C% "Generating library index... "
type ..\..\index.head > index.html

for /f "delims=, tokens=1-5" %%I IN ('%GREP_C% "^\(DocTag\|Package\) " %~fs0 ^| %GREP_C% -v "{}" ^| %SED_C% -e "s/.*{\([^}]*\)}.*/\1/" -e "s/^Package \([^ ]*\).*/\1/" -e "s/^DocTag //" ^| %SORT_C%') do (
  if "%%J" equ "MANUAL" (
    if "%%M" equ "" (
      set URL=%%I
    ) else (
      set URL=%%M
    )
    for /f "delims=" %%X in ('echo !URL!^| %TR_C% [A-Z] [a-z]') do set URL=%%X
    %PRINTF_C% "<tr><td class=\"module\"><a href=\"!URL!/index.html\">%%I %%L</a></td><td><div class=\"info\">\n">> index.html
    echo %%K>> index.html
  ) else (
    if "%%J" equ "LOOKUP" (
      set PACKAGE=%%K
      if "%%L" equ "" (
        set URL=%%I
      ) else (
        set URL=%%K
      )
    ) else (
      SET PACKAGE=%%I
      if "%%J" equ "LOCATE" (
        set URL=%%K
      ) else (
        set URL=%%I
      )
    )
    for /f "delims=" %%D in ('ocamlfind list -describe ^| %GREP_C% -i "^^!PACKAGE! " ^| %SED_C% -e "s/^^[^^ ]* *//"') do (
      for /f %%L in ('ocamlfind list ^| %GREP_C% -i "^^!PACKAGE! " ^| %SED_C% -e "s/.*version: \([0-9.]*\).*/\1/"') do (
        for /f "delims=" %%X in ('echo !URL!^| %TR_C% [A-Z] [a-z]') do set URL=%%X
        %PRINTF_C% "<tr><td class=\"module\"><a href=\"!URL!/index.html\">%%I %%L</a></td><td><div class=\"info\">\n">>index.html
      )
      echo %%D>> index.html
    )
  )
  %PRINTF_C% "</div>\n</td></tr>\n">> index.html
)

%PRINTF_C% "</table>\n</body>\n</html>\n">> index.html
echo done

endlocal

popd

echo %TIME%

if %SAV_START% equ 1 sc start SAVService

pause

goto :EOF

:Path
echo %PATH%| %SED_C% -e "s/;/\r\n/g"
goto :EOF

:Elevate
echo This script needs to be run with administrator permissions
pause
goto Docs

:MakeRoot
if not exist %ROOT% (
  echo Creating %ROOT%
  mkdir %ROOT%
  echo Y| cacls %ROOT% /T /G BUILTIN\Administrators:F "NT AUTHORITY\SYSTEM":F BUILTIN\Users:R > nul
)
goto :EOF

:Docs
%GREP_C% "^\(@rem\|#\|Package\)" %~fs0 | %SED_C% -e "s/^\(@rem\|#\) \?//" | %SED_C% -e "s/{[^}]*}//" -e "s/ *$//" -e "s/^Package \([^ ]*\)\( \[.*\]\)\?/Compile \1/" | %LESS_C%
goto :EOF

From here on, this is the bash script build. Lines to transfer to the bash script begin with a =
Documentation lines begin #
=#!/bin/bash
=# 16-Jan-2012 @ DRA
=
=# This script should be invoked by build.cmd and receives the following environment variables
=#   ROOT (C:\Dev)
=#   FLAVOUR (e.g. -MSVC)
=#   OCAMLROOT (C:\Dev\OCaml)
=#   CYGROOT (C:\cygwin)
=#   CYGREPO (D:\Repositories\Cygwin)
=#   MACHINE (e.g. i686-w64-mingw32)
=
=if [ -z $ROOT ] ; then
=  echo This script is intended to be invoked by build.cmd>&2
=  echo To invoke manually, set ROOT, FLAVOUR, OCAMLROOT, CYGROOT, CYGREPO and MACHINE>&2
=  exit 1
=fi
=
=OCAMLROOT_C=`cygpath -u $OCAMLROOT`
=
=cd `cygpath -u $ROOT`/Src
=
# ***
# *** Support binaries
# ***
# The following additional tools have to be copied to C:\Dev\OCaml\bin
# From flexdll-bin-0.31.zip:
#   + flexlink.exe (this file is recompiled after OCaml is built)
# From Cygwin's bin directory:
#   + i686-w64-mingw32-ar and i686-w64-mingw32-ranlib (needed by ocamlopt to build libraries)
#   + i686-w64-mingw32-gcc (needed by ocamlc and ocamlopt to compile C stubs)
#   + i686-w64-mingw32-as (needed by ocamlopt)
#   + i686-w64-mingw32-dlltool (needed to create import libraries)
#   + i686-w64-mingw32-cpp as cpp.exe (needed by OCamlNet's rpc-generator)
# All the dependent DLLs for the Cygwin binaries must be linked in C:\Dev\OCaml\bin as well in addition to the dependencies for GCC's cc1.exe
=if [ "$1" = "" ]
=then
=  # Extract flexlink
=
=  unzip -o flexdll-bin-0.31.zip flexlink.exe -d $OCAMLROOT_C/bin
=
=  # Initialise OCAMLROOT/bin with required binaries
=
=  SCAN=`find -L /lib -name cc1.exe`
=
=  for file in cpp $MACHINE-{as,ar,ranlib,gcc,dlltool} cygpath bash git
=  do
=    if [ -e /bin/$MACHINE-$file.exe ] ; then
=      TARGET=$MACHINE-$file.exe
=    else
=      TARGET=$file.exe
=    fi
=    SCAN="$SCAN /bin/$TARGET"
=  # It's not clear why -e doesn't work on Windows symlinks - bug or intended?
=    if [ ! -h $OCAMLROOT_C/bin/$file.exe ] ; then
=      cmd /c "mklink $OCAMLROOT\\bin\\$file.exe $CYGROOT\\bin\\$TARGET"
=    fi
=  done
=
=  # Now ensure that all their Cygwin DLL dependencies exist
=
=  for path in `for i in $SCAN; do ldd $i; done | fgrep -v "/cygdrive/" | fgrep -vi "cygwin1.dll" | sed -e "s/.* => \([^ ]*\) .*/\1/" | sort | uniq`
=  do
=    file=`basename $path`
=    if [ ! -e $OCAMLROOT_C/bin/$file ] ; then
=      cmd /c "mklink $OCAMLROOT\\bin\\$file `cygpath -w $path`"
=    fi
=  done
=
=  OCAMLROOT_MC=`cygpath -m $OCAMLROOT | sed -e 's/\//\\\\\//g'`
=  TCLROOT_MC=`cygpath -m $TCLROOT | sed -e 's/\//\\\\\//g'`
=  export OCAMLROOT_MC OCAMLROOT_C OCAMLROOT TCLROOT TCLROOT_MC
=  POS=0
=  touch build/changed.stamp
=  MASK=1
=  for i in `seq $NUMBER_OF_PROCESSORS`
=#  for i in 1
=  do
=    cmd /c start /high /affinity `printf "0x%x" $MASK` mintty --size 269,7 --position 0,$POS build/build $i &
=    let MASK*=2
=    let POS+=125
=#    build/build $i
=  done
=
=  while [ ! -f build/.complete ]
=  do
=    sleep 1
=  done
=
=#  updatedb
=else
=  # Build Daemon
=  COMPLETE=0
=  clear
=  echo Build Daemon $1 -- waiting for job
=  while [ $COMPLETE -eq 0 ]
=  do
=    BUILD=
=    BLOCKED=0
=#   lockfile -1 build/master.lock
=    if [ -f build/.complete -o ! -f build/build-$1.stamp -o build/changed.stamp -nt build/build-$1.stamp ]
=    then
=      COMPLETE=1
=      for line in `sed -e "s/ .*//" build/packages`
=      do
=        if [ ! -f build/failure.$line -a ! -f build/blocked.$line -a ! -f build/package.$line -a ! -f build/build.$line ]
=        then
=          MISSING=0
=          COMPLETE=0
=          for deps in `grep "^$line " build/packages | sed -e "s/^[^ ]* //"`  
=          do
=            if [ ! -f build/package.$deps ]
=            then
=              if [ -f build/failure.$deps ]
=              then
=                lockfile -1 build/master.lock
=                if [ ! -f build/blocked.$line ]
=                then
=                  touch build/blocked.$line
=                  BLOCKED=1
=                  rm -f build/build-$1.stamp
=                fi
=                rm -f build/master.lock
=              fi
=              MISSING=1
=            fi
=          done
=          if [ $MISSING -eq 0 ]
=          then
=            lockfile -1 build/master.lock
=            if [ ! -f build/build.$line ]
=            then
=              BUILD=$line
=              touch build/build.$line
=              rm -f build/master.lock
=              break
=            fi
=            rm -f build/master.lock
=          fi
=        elif [ ! -f build/failure.$line -a ! -f build/blocked.$line -a ! -f build/package.$line -a -f build/build.$line ]
=        then
=          COMPLETE=0
=        fi
=      done
=      if [ "$BUILD" = "" -a $BLOCKED -eq 0 ]
=      then
=        touch build/build-$1.stamp
=      fi
=    fi
=#    rm -f build/master.lock
=    if [ ! "$BUILD" = "" ]
=    then
=      rm -f build/build-$1.stamp
=      build/build-package $BUILD 2>&1 | tee build/log.$BUILD
=      if [ -f build/success.$BUILD ]
=      then
=        mv build/log.$BUILD build/package.$BUILD
=        rm build/success.$BUILD
=      else
=        mv build/log.$BUILD build/failure.$BUILD
=        rm -f build/failed.$BUILD
=      fi
=      rm build/build.$BUILD
=      touch build/changed.stamp
=      clear
=      echo Build Daemon $1 -- waiting for job
=    elif [ $COMPLETE -eq 0 ]
=    then
=      sleep 2
=    fi
=  done
=  touch build/.complete
=fi
From here on is the package build database.
Lines transferred to build-package are prefixed with *
Documentation lines are prefixed #
*#!/bin/bash
*# 8-Sep-2012 @ DRA
*
*BUILDING=$1
*
*testPackage () {
*  ocamlfind query $1 > /dev/null 2>&1 && touch build/success.$BUILDING || touch build/failed.$BUILDING
*}
*
*testSource () {
*  if [ -f $1 ]
*  then
*    touch build/success.$BUILDING
*  else
*    touch build/failed.$BUILDING
*  fi
*}
*
*testFile () {
*  testSource $OCAMLROOT_C/$1
*}
*
*case "$1" in
*  "")
*# The purpose of this package is to allow retrieving of repositories to be delayed
Package Repos {}
*testSource build/build
*# The purpose of this package is to allow C libraries to be delayed
Package Support {}
*testSource build/build
#
# ***
# *** OCaml Installation
# ***
#
Package FlexDLL {}
#   Homepage: http://alain.frisch.fr/flexdll.html
#   Files   : http://alain.frisch.fr/flexdll/flexdll-0.31.tar.gz
#             http://alain.frisch.fr/flexdll/flexdll-bin-0.31.zip
*tar --transform=s/^flexdll/flexdll-0.31/ -xzf flexdll-0.31.tar.gz
*cd flexdll-0.31
*make CHAINS=mingw support
*for i in flexdll_{initer_,}mingw.o flexdll.h
*do
*  cp $i $OCAMLROOT_C/bin
*  echo cp $i $OCAMLROOT_C/bin
*done
*cd ..
*testFile bin/flexdll.h
#
Package OCaml [FlexDLL] {}
#   Homepage: http://caml.inria.fr/download.en.html
#   URLS to be updated after 4.01.0 released...
#   Files   : http://caml.inria.fr/pub/distrib/ocaml-4.01/ocaml-4.01.0.tar.gz
#             http://caml.inria.fr/pub/distrib/ocaml-4.01/ocaml-4.01-refman-html.tar.gz
#   Patches : ocaml-4.01.0-PR5325.patch -- Fixes a blocking problem with socket functions (accepted upstream, regression problems)
#             ocaml-4.01.0-PR6165.patch -- Restores a version of old newline handling in the compiler's lexer (accepted upstream)
#             Compile against Tcl/Tk 8.6 instead of 8.5 (reported upstream - irrelevant from OCaml 4.02.0 as labltk removed)
#   Dependencies: FlexDLL
*tar -xzf ocaml-4.01.0.tar.gz
*tar --transform=s/^htmlman/docs/ -xzf ocaml-4.01-refman-html.tar.gz
*cd docs
*patch -p0 -i ../ocaml-4.01-refman-html.patch
*cd ..
*for i in 5325 6165
*do
*  patch -p0 -i ocaml-4.01.0-PR$i.patch
*done
*cd ocaml-4.01.0
*cp config/m-nt.h config/m.h
*cp config/s-nt.h config/s.h
*sed -e "18s/=.*/=$OCAMLROOT_MC/" -e "159s/=.*/=$TCLROOT_MC/" -e "161s/85/86/g" config/Makefile.mingw > config/Makefile
*make -f Makefile.nt world opt opt.opt install
*sed -i -e 's/\//\\/g' $OCAMLROOT_C/lib/ld.conf
*cd ../flexdll-0.31
*# This command is needed temporarily -- can't work out the best patch for FlexDLL to fix this
*i686-w64-mingw32-windres version.rc version_res.o
*make flexlink.exe
*cp flexlink.exe $OCAMLROOT_C/bin
*cd ..
*testFile bin/ocamlc.opt.exe
#
# ***
# *** Build Libraries
# ***
Package Findlib [OCaml] {FindLib Guide,MANUAL,Package manager user guide,1.4,findlib/guide}
#   Homepage: http://projects.camlcity.org/projects/findlib.html
#   Files   : http://download.camlcity.org/download/findlib-1.4.1.tar.gz
Docs findlib-1.4.1/doc/guide-html/* guide
Docs findlib-1.4.1/doc/ref-html/* ref
DocsRemove TIMESTAMP
DocTag FindLib,LOCATE,findlib/ref
*tar -xzf findlib-1.4.1.tar.gz
*cd findlib-1.4.1
*./configure
*make all opt install
*mkdir $OCAMLROOT_C/lib/site-lib/stublibs
*echo $OCAMLLIB\\site-lib\\stublibs>> $OCAMLROOT_C/lib/ld.conf
*cd ..
*testFile bin/ocamlfind.exe
#
Package ExtLib [Findlib]
#   Homepage: http://code.google.com/p/ocaml-extlib
#   Files   : http://ocaml-extlib.googlecode.com/files/extlib-1.6.1.tar.gz
#   Patches : extlib-1.6.1.patch -- Fixes the detection of the build environment in install.ml (submitted upstream, but apparently ignored)
Docs extlib-1.6.1/doc/*
*tar -xzf extlib-1.6.1.tar.gz
*patch -p0 -i extlib-1.6.1.patch
*cd extlib-1.6.1
*ocaml unix.cma install.ml <<EOF
*3
*y
*y
*EOF
*cd ..
*testPackage extlib
#
Package Calendar [Findlib]
#   Homepage: http://forge.ocamlcore.org/projects/calendar
#   Files   : http://forge.ocamlcore.org/frs/download.php/915/calendar-2.03.2.tar.gz
Docs calendar-2.03.2/doc/*
*tar -xzf calendar-2.03.2.tar.gz
*cd calendar-2.03.2
*./configure
*make all install
*cd ..
*testPackage calendar
#
Package PCRE [Support] {PCRE,MANUAL,Perl Compatible Regular Expression (C documentation),8.34}
#   Homepage: http://www.pcre.org
#   Files   : ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.34.tar.gz
Docs pcre-8.34/doc/html/*
DocsRemove README.txt
DocsRemove NON-AUTOTOOLS-BUILD.txt
*tar -xzf pcre-8.34.tar.gz
*cd pcre-8.34
*./configure --prefix="$OCAMLROOT_MC" --includedir="$OCAMLROOT_MC/lib" --disable-cpp --enable-utf8 --host=i686-w64-mingw32 --build=i686-pc-cygwin
*sed -i -e "1s/$/\n\nPATH=\/bin:\$PATH/" pcre-config
*# @@DRA Man pages to C:/Dev/OCaml/man
*make all install
*cat > $OCAMLROOT_C/bin/pcre-config.cmd <<EOF
*@setlocal
*@echo off
*bash $OCAMLROOT_C/bin/pcre-config %*
*EOF
*cd ..
*testFile lib/pcre.h
#
Package PCRE-OCaml [Findlib PCRE] {PCRE-OCaml,LOOKUP,pcre}
#   Homepage: https://bitbucket.org/mmottl/pcre-ocaml
#   Files   : http://cdn.bitbucket.org/mmottl/pcre-ocaml/downloads/pcre-ocaml-7.0.4.tar.gz
#   Patches : Temporary use of --override to deal with a bug in OASIS 0.4
Docs pcre-ocaml-7.0.4/docs/api/*
*tar -xzf pcre-ocaml-7.0.4.tar.gz
*cd pcre-ocaml-7.0.4
*ocaml setup.ml -configure --docdir ./docs --override ocamlfind ocamlfind
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage pcre
#
Package CSV [Findlib]
#   Homepage: http://forge.ocamlcore.org/projects/csv
#   Files   : http://forge.ocamlcore.org/frs/download.php/1376/csv-1.3.3.tar.gz
#   Patches : Temporary use of --override to deal with a bug in OASIS 0.4
Docs csv-1.3.3/docs/api/*
*tar -xzf csv-1.3.3.tar.gz
*cd csv-1.3.3
*ocaml setup.ml -configure --docdir ./docs --override ocamlfind ocamlfind
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage csv
#
Package Batteries [Findlib]
#   Homepage: http://batteries.forge.ocamlcore.org
#   Files   : http://forge.ocamlcore.org/frs/download.php/1363/batteries-2.2.tar.gz
Docs batteries-2.2/_build/batteries.docdir/*
DocsRemove html.stamp
*tar -xzf batteries-2.2.tar.gz
*cd batteries-2.2
*make all doc install
*cd ..
*testPackage batteries
#
Package PGOCaml [Findlib Batteries PCRE-OCaml CSV Calendar]
#   Homepage: http://forge.ocamlcore.org/projects/pgocaml
#   Files   : http://forge.ocamlcore.org/frs/download.php/1099/pgocaml-1.7.1.tgz
#   Patches : pgocaml-1.7.1-command.patch -- Adds PGCOMMAND environment variable support (private patch)
#             pgocaml-1.7.1-4.00.1-win32.patch -- Works around the faulty patch for PR5325 in 4.00.1 (private patch - remove when PR5325 properly fixed)
#             pgocaml-1.7.1-compile.patch -- Adds support for the "command" directive to PGSQL (not yet submitted upstream)
Docs pgocaml-1.7.1/docs/api/*
*tar -xzf pgocaml-1.7.1.tgz
*patch -p0 -i pgocaml-1.7.1-4.00.1-win32.patch
*patch -p0 -i pgocaml-1.7.1-command.patch
*patch -p0 -i pgocaml-1.7.1-compile.patch
*cd pgocaml-1.7.1
*ocaml setup.ml -configure --docdir ./docs
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage pgocaml
#
Package ZLib [Support] {}
#   Homepage: http://zlib.net
#   Files   : http://zlib.net/zlib-1.2.8.tar.gz
*tar -xzf zlib-1.2.8.tar.gz
*cd zlib-1.2.8
*make BINARY_PATH=$OCAMLROOT_MC/bin LIBRARY_PATH=$OCAMLROOT_MC/lib INCLUDE_PATH=$OCAMLROOT_MC/lib SHARED_MODE=1 PREFIX=i686-w64-mingw32- -f win32/Makefile.gcc all install
*cd ..
*testFile lib/libz.a
#
Package Zip [Findlib ZLib]
#   Homepage: http://forge.ocamlcore.org/projects/camlzip
#   Files   : http://forge.ocamlcore.org/frs/download.php/1037/camlzip-1.05.tar.gz
#   Patches : camlzip-1.05.patch -- improves META file (based on old patch) and fixes Windows install (not submitted upstream)
#   Notes   : To link against the DLL, specify -lzdll instead of -lzl
Docs camlzip-1.05/doc/*
*tar -xzf camlzip-1.05.tar.gz
*patch -p0 -i camlzip-1.05.patch
*cd camlzip-1.05
*sed -i -e "s/\/usr\/local/C:\/Dev\/OCaml/" Makefile
*make ZLIB_LIBDIR=$OCAMLROOT_MC/lib ZLIB_INCLUDE=$OCAMLROOT_MC/lib all allopt
*mkdir doc && ocamldoc -d doc -html gzip.mli zip.mli
*make install-findlib
*cd ..
*testPackage zip
#
Package OpenSSL [Support] {}
#   Homepage: http://www.openssl.org
#   Files   : http://www.openssl.org/source/openssl-1.0.1f.tar.gz
*# Note that when we used to have cygwin1.dll in $OCAMLROOT\bin, Perl used to fail when installing this package
*tar -xzf openssl-1.0.1f.tar.gz
*cd openssl-1.0.1f
*perl Configure mingw shared --prefix=$OCAMLROOT_MC --cross-compile-prefix=i686-w64-mingw32-
*make
# install_sw installs software only, skipping documentation - which, for some reason, is very slow to install
*make install_sw
*mv $OCAMLROOT_C/include/openssl $OCAMLROOT_C/lib
*rmdir $OCAMLROOT_C/include
*cd ..
*testFile lib/libssl.a
#
Package SSL [FindLib OpenSSL]
#   Homepage: http://sourceforge.net/projects/savonet/files/ocaml-ssl
#   Files   : http://ignum.dl.sourceforge.net/project/savonet/ocaml-ssl/0.4.6/ocaml-ssl-0.4.6.tar.gz
Docs ocaml-ssl-0.4.6/doc/html/*
*tar -xzf ocaml-ssl-0.4.6.tar.gz
*cd ocaml-ssl-0.4.6
*./configure --host=i686-w64-mingw32 --build=mingw32 LDFLAGS=-L$OCAMLROOT_MC/lib CFLAGS=-I$OCAMLROOT_MC/lib
*make AR=i686-w64-mingw32-ar all
*make install
*cd ..
*testPackage ssl
#
Package CryptoKit [Findlib ZLib]
#   Homepage: http://forge.ocamlcore.org/projects/cryptokit
#   Files   : http://forge.ocamlcore.org/frs/download.php/1229/cryptokit-1.9.tar.gz
Docs cryptokit-1.9/docs/cryptokit/*
*tar -xzf cryptokit-1.9.tar.gz
*cd cryptokit-1.9
*ocaml setup.ml -configure --enable-zlib --zlib-libdir C:/Dev/OCaml/lib --docdir ./docs
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage cryptokit
#
Package OCamlNet [FindLib PCRE-OCaml SSL Zip CryptoKit] {OCamlNet,MANUAL,Enhanced system platform library for OCaml,3.7.3}
#   Homepage: http://projects.camlcity.org/projects/ocamlnet.html
#   Files   : http://download.camlcity.org/download/ocamlnet-3.7.3.tar.gz
Docs ocamlnet-3.7.3/doc/html-main/*
*tar -xzf ocamlnet-3.7.3.tar.gz
*cd ocamlnet-3.7.3
*./configure -enable-ssl -enable-tcl -enable-crypto -enable-zip -enable-full-pcre -cpp $OCAMLROOT_MC/bin/cpp -equeue-tcl-defs -I$TCLROOT_MC/include
*make all opt install
*cd ..
*testPackage netstring
#
Package JSON-Wheel [Findlib OCamlNet]
#   Homepage: http://martin.jambon.free.fr/json-wheel.html
#   Files   : http://martin.jambon.free.fr/json-wheel-1.0.6.tar.gz
#   Patches : json-wheel-1.0.6.patch -- Fixes compilation in OCaml 4.00 (auto-appending of .exe seems to have changed) (not submitted upstream - deprecated package)
Docs json-wheel-1.0.6/html/*
*tar --transform=s/^json-wheel/json-wheel-1.0.6/ -xzf json-wheel-1.0.6.tar.gz
*patch -p0 -i json-wheel-1.0.6.patch
*cd json-wheel-1.0.6
*make WIN32=1 all opt install
*cd ..
*testPackage json-wheel
#
Package JSON-static [Findlib] {}
#   Homepage: http://martin.jambon.free.fr/json-static.html
#   Files   : http://martin.jambon.free.fr/json-static-0.9.8.tar.gz
#   Patches : Line 23 of the Makefile is deleted: the symbolic link created causes problems for ocamlc
*tar -xzf json-static-0.9.8.tar.gz
*cd json-static-0.9.8
*sed -i -e "23d" Makefile
*make all install
*cd ..
*testPackage json-static
#
Package SpiderMonkey [Support] {}
#   Homepage: https://developer.mozilla.org/en/SpiderMonkey
#   Files   : http://ftp.mozilla.org/pub/mozilla.org/js/js-1.7.0.tar.gz
#   Patches : js-1.7.0.patch -- Enables compilation under MinGW (submitted back to original author with no response)
#             The transformations to src/jsnum.c are temporary as these are more likely a compiler issue
*tar --transform=s/^js/js-1.7.0/ -xzf js-1.7.0.tar.gz
*patch -p0 -i js-1.7.0.patch
*cd js-1.7.0/src
*sed -i -e 's/<float.h>/"\/usr\/i686-w64-mingw32\/sys-root\/mingw\/include\/float.h"/' -e "s/MCW_EM/_MCW_EM/g" jsnum.c
*make -C fdlibm -f Makefile.ref OS_OBJTYPE=-MinGW-Cygwin- BUILD_OPT=1 AR=i686-w64-mingw32-ar
*make -f Makefile.ref OS_OBJTYPE=-MinGW-Cygwin- BUILD_OPT=1 AR=i686-w64-mingw32-ar
*for i in *.{h,tbl,msg} WINNT-MinGW-Cygwin-6.1_OPT.OBJ/*.{h,a,def}; do cp $i $OCAMLROOT_MC/lib && echo cp $i $OCAMLROOT_MC/lib; done
*cp WINNT-MinGW-Cygwin-6.1_OPT.OBJ/libjs.dll $OCAMLROOT_MC/bin
*cd ../..
*testFile lib/libjs.a
#
Package SpiderCaml [Findlib SpiderMonkey]
#   Homepage: http://alain.frisch.fr/soft.html#spider
#   Files   : http://yquem.inria.fr/~frisch/SpiderCaml/download/SpiderCaml-0.2.tar.gz
#   Patches : SpiderCaml-0.2-print.patch -- adds print functions, including for the toplevel (accepted upstream)
#             SpiderCaml-0.2-array.patch -- logic corrected to prevent a crash with array handling (accepted upstream)
#             SpiderCaml-0.2-conf.patch  -- patches to Makefile.conf for Windows building (not submitted upstream?)
#             SpiderCaml-0.2-enum.patch  -- adds enumerate method to jsobj (submitted upstream)
#   Notes   : make install must be a separate invocation of make
Docs SpiderCaml-0.2/doc/spiderCaml/html/*
*tar -xzf SpiderCaml-0.2.tar.gz
*patch -p0 -i SpiderCaml-0.2.patch
*for i in conf enum print array; do patch -p0 -i SpiderCaml-0.2-$i.patch; done
*cd SpiderCaml-0.2
*make all opt htdoc
*make install
*cd ..
*testPackage spiderCaml
#
*# @@DRA Would like a way to indicate that this package should be hidden from the docs...
*# The idea with packages which have to be retrieved from repositories is that we split them into Repo-Foo and Foo
*# so that the packages get retrieved at the beginning of the build process
Package Repo-SHA [Repos] {}
*git clone https://github.com/vincenthz/ocaml-sha.git ocaml-sha-1.9
*testSource ocaml-sha-1.9/Makefile
Package SHA [Findlib Repo-SHA]
*#   Homepage: https://github.com/vincenthz/ocaml-sha
*#   Files   : git 
*#   Patches : The patch to snprintf may be because of a bug in flexlink (submitted upstream)
*#   Dependencies: Findlib
Docs ocaml-sha-1.9/html/*
*cd ocaml-sha-1.9
*git checkout ocaml-sha-v1.9
*rm -rf .git
*#sed -i -e "s/snprintf/_snprintf/" *.c
*make all doc bins install
*cd ..
*testPackage sha
#
Package OCamLDAP [Findlib OCamlNet SSL]
#   Homepage: https://forge.ocamlcore.org/projects/ocamldap/
#   Files   : http://switch.dl.sourceforge.net/project/ocamldap/ocamldap/ocamldap-2.1.8/ocamldap-2.1.8.tar.bz2
#   Patches : ocamldap-2.1.8.patch -- fixes version in META, compilation under Windows (no sigalrm), and a protocol error handling SASL (not yet submitted upstream)
Docs ocamldap-2.1.8/doc/ocamldap/html/*
*tar -xjf ocamldap-2.1.8.tar.bz2
*patch -p0 -i ocamldap-2.1.8.patch
*cd ocamldap-2.1.8
*make all opt
*make install
*cd ..
*testPackage ocamldap
#
Package cppo [OCaml] {CPPO,MANUAL,C preprocessor for OCaml,0.9.3}
#   Homepage: http://mjambon.com/cppo.html
#   Files   : http://mjambon.com/releases/cppo/cppo-0.9.3.tar.gz
Docs cppo-0.9.3/index.html
*tar -xzf cppo-0.9.3.tar.gz
*cd cppo-0.9.3
*sed -i -e "s/-o cppo/\0.exe/" Makefile
*make BINDIR=$OCAMLROOT_MC/bin default install
*echo "<html><head><title>CPPO 0.9.3</title></head><body><pre>" > index.html
*cat README >> index.html
*echo "</pre></body></html>" >> index.html
*cd ..
*testFile bin/cppo.exe
#
Package camlmix [OCaml] {}
#   Homepage: http://mjambon.com/camlmix
#   Files   : http://mjambon.com/camlmix/camlmix-1.3.0.tar.gz
*tar -xzf camlmix-1.3.0.tar.gz
*cd camlmix-1.3.0
*make MINGW=1 all opt
*make MINGW=1 install
*cd ..
*testFile bin/camlmix.exe
#
Package caml2html [camlmix Findlib] {}
#   Homepage: http://mjambon.com/caml2html.html
#   Files   : http://mjambon.com/releases/caml2html/caml2html-1.4.3.tar.gz
*tar -xzf caml2html-1.4.3.tar.gz
*cd caml2html-1.4.3
*sed -i -e "s/755 caml2html /755 caml2html.exe /" Makefile
*make all opt
*make install
*cd ..
*testPackage caml2html
#
Package easy-format [caml2html]
#   Homepage: http://mjambon.com/easy-format.html
#   Files   : http://mjambon.com/releases/easy-format/easy-format-1.0.2.tar.gz
Docs easy-format-1.0.2/ocamldoc/*
*tar -xzf easy-format-1.0.2.tar.gz
*cd easy-format-1.0.2
*make default doc install
*mv easy_format_example.html ocamldoc
*sed -i -e 's/<\/body>/<p>A <a href="easy_format_example.html">full example<\/a> is also available.<\/p>\0/' index.html
*cd ..
*testPackage easy-format
#
Package biniou [easy-format]
#   Homepage: http://mjambon.com/biniou.html
#   Files   : http://mjambon.com/releases/biniou/biniou-1.0.9.tar.gz
Docs biniou-1.0.9/doc/*
*tar -xzf biniou-1.0.9.tar.gz
*cd biniou-1.0.9
*make default doc install
*cd ..
*testPackage biniou
#
Package Yojson [Findlib cppo biniou]
#   Homepage: http://mjambon.com/yojson.html
#   Files   : http://mjambon.com/releases/yojson/yojson-1.1.8.tar.gz
Docs yojson-1.1.8/doc/*
*tar -xzf yojson-1.1.8.tar.gz
*cd yojson-1.1.8
*make default doc install
*cd ..
*testPackage yojson
#
Package Menhir [Findlib] {}
#   Homepage: http://gallium.inria.fr/~fpottier/menhir/
#   Files   : http://gallium.inria.fr/~fpottier/menhir/menhir-20130911.tar.gz
*tar -xzf menhir-20130911.tar.gz
*cd menhir-20130911
# @@DRA Not sure that files are being installed to the ideal place (standard library to share/menhir?)
# @@DRA Documentation is a PDF which could be installed to the docs tree instead
# @@DRA Man pages to C:/Dev/OCaml/man
*make PREFIX=$OCAMLROOT_MC install
*cd ..
*testPackage menhirLib
#
Package Merlin [Yojson Menhir] {}
#   Homepage: https://github.com/def-lkb/merlin
#   Files   : https://codeload.github.com/the-lambda-church/merlin/tar.gz/v1.6
#   Patches : merlin-1.6.patch -- various Windows-support fixes (pull request submitted upstream)
*tar -xzf merlin-1.6.tar.gz
*patch -p0 -i merlin-1.6.patch
*cd merlin-1.6
*./configure --prefix $OCAMLROOT_MC --stdlib $OCAMLROOT_MC/lib
*make
*make install
*cd ..
*testFile bin/ocamlmerlin.exe
#
Package type_conv [Findlib]
#   Homepage: http://janestreet.github.io/
#   Files   : https://ocaml.janestreet.com/ocaml-core/109.60.00/individual/type_conv-109.60.01.tar.gz
Docs type_conv-109.60.01/_build/api-pa_type_conv.docdir/*
*tar -xzf type_conv-109.60.01.tar.gz
*cd type_conv-109.60.01
*ocaml setup.ml -configure
*ocaml setup.ml -build
*# type_conv OASIS file doesn't generate documentation
*mkdir -p _build/api-pa_type_conv.docdir
*cd lib
*ocamlfind ocamldoc -html -colorize-code -d ../_build/api-pa_type_conv.docdir -package camlp4 -syntax camlp4o pa_type_conv.mli
*cd ..
*ocaml setup.ml -install
*cd ..
*testPackage type_conv
#
Package ODN [type_conv] {}
#   Homepage: https://forge.ocamlcore.org/projects/odn
#   Files   : https://forge.ocamlcore.org/frs/download.php/1310/ocaml-data-notation-0.0.11.tar.gz
*tar -xzf ocaml-data-notation-0.0.11.tar.gz
*cd ocaml-data-notation-0.0.11
*ocaml setup.ml -configure
*ocaml setup.ml -build
*ocaml setup.ml -install
*cd ..
*testPackage odn
#
Package ocamlmod [Findlib] {}
#   Homepage: https://forge.ocamlcore.org/projects/ocamlmod
#   Files   : http://forge.ocamlcore.org/frs/download.php/1350/ocamlmod-0.0.7.tar.gz
#   Patches : Temporary use of --override to deal with a bug in OASIS 0.4
*tar -xzf ocamlmod-0.0.7.tar.gz
*cd ocamlmod-0.0.7
*ocaml setup.ml -configure --prefix $OCAMLROOT_MC --override ocamlfind ocamlfind
*ocaml setup.ml -build
*ocaml setup.ml -install
*cd ..
*testFile bin/ocamlmod.exe
#
Package ocamlify [Findlib] {}
#   Homepage: https://forge.ocamlcore.org/projects/ocamlify
#   Files   : http://forge.ocamlcore.org/frs/download.php/1209/ocamlify-0.0.2.tar.gz
*tar -xzf ocamlify-0.0.2.tar.gz
*cd ocamlify-0.0.2
*ocaml setup.ml -configure --prefix $OCAMLROOT_MC
*ocaml setup.ml -build
*ocaml setup.ml -install
*cd ..
*testFile bin/ocamlify.exe
#
Package fileutils [Findlib]
#   Homepage: https://forge.ocamlcore.org/projects/ocaml-fileutils
#   Files   : http://forge.ocamlcore.org/frs/download.php/1194/ocaml-fileutils-0.4.5.tar.gz
Docs ocaml-fileutils-0.4.5/docs/api/*
*tar -xzf ocaml-fileutils-0.4.5.tar.gz
*cd ocaml-fileutils-0.4.5
*ocaml setup.ml -configure --docdir ./docs
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage fileutils
#
Package expect [PCRE-OCaml Batteries]
#   Homepage: https://forge.ocamlcore.org/projects/ocaml-expect
#   Files   : http://forge.ocamlcore.org/frs/download.php/1372/ocaml-expect-0.0.5.tar.gz
#   Patches : Temporary use of --override to deal with a bug in OASIS 0.4
Docs ocaml-expect-0.0.5/docs/expect/*
*tar -xzf ocaml-expect-0.0.5.tar.gz
*cd ocaml-expect-0.0.5
*ocaml setup.ml -configure --docdir ./docs --override ocamlfind ocamlfind
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage expect
#
Package OUnit [Findlib]
#   Homepage: http://ounit.forge.ocamlcore.org/
#   Files   : http://forge.ocamlcore.org/frs/download.php/1258/ounit-2.0.0.tar.gz
#   Patches : ounit-2.0.0.patch -- improved English in the manual (submitted upstream)
Docs ounit-2.0.0/docs/*
*tar -xzf ounit-2.0.0.tar.gz
*patch -p0 -i ounit-2.0.0.patch
*cd ounit-2.0.0
*ocaml setup.ml -configure --docdir ./docs
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testPackage oUnit
#
Package OASIS [ODN ocamlmod ocamlify]
#   Homepage: http://oasis.forge.ocamlcore.org/
#   Files   : http://forge.ocamlcore.org/frs/download.php/1388/oasis-0.4.3.tar.gz
#   Patches : Temporary use of --override to deal with a bug in OASIS 0.4
# @@DRA The manual could be integrated into this (using Showdown)
# @@DRA There is a bug in OASIS installation which means that the documents can't be picked up from where we expect
Docs oasis-0.4.3/_build/src/api-oasis.docdir/*
DocsRemove html.stamp
*tar -xzf oasis-0.4.3.tar.gz
*cd oasis-0.4.3
*ocaml setup.ml -configure --prefix $OCAMLROOT_MC --docdir ./docs --override ocamlfind ocamlfind
*ocaml setup.ml -build
*ocaml setup.ml -doc
*ocaml setup.ml -install
*cd ..
*testFile bin/oasis.exe
#
*;;
*esac
