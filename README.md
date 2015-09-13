# OCaml 4.01.0 mingw64 x86 Port Build Scripts

### Background

These scripts have been provided for historic interest (and to preserve anything useful from the patches and build information).

**You must have administrative access to any computer on which you wish to install OCaml using these scripts!**

## Prerequisites
1. Download Cygwin's x86 setup program from https://www.cygwin.com/setup-x86.exe and save it to a directory (e.g. `C:\Cygwin-Repository\`).
2. Run the Cygwin setup program and use the "Download Without Installing" option to download a complete repository to the directory in which you placed `setup-x86.exe`. **Do not install Cygwin**.
3. Download an x86 installer for the 8.6 branch of ActiveTcl from www.activestate.com/activetcl/downloads

## Installation procedure

1. By default, the installer will install files to `C:\Dev` (`%ROOT%`), will install Cygwin to `C:\cygwin` (`%CYGROOT%`) and will assume that Cygwin setup and the repository are in `C:\Cygwin-Repository` (`%CYGREPO%`). Edit `build-config.cmd` if you need to change any of these.
2. From an elevated command prompt, create `%ROOT%` by running `build --make-root` (exit the command prompt after doing this)
3. Run the ActiveTcl installer you downloaded earlier *as an administrator*:
  * Install for all users
  * It's not necessary to enable the 'Add ".tcl" to your executable path extensions' or 'Associate ".tcl" extension to ActiveTcl 8.6' options
  * Install to `%ROOT%\Tcl`
  * A program group is not required
4. From the System Control Panel applet, edit the system environment variables so that:
  * `LIB` includes `%ROOT%\Tcl\lib` (`LIB` is semicolon-delimited)
  * `CYGWIN` includes `winsymlinks:native` and `nodosfilewarning` options (`CYGWIN` is space-delimited)
  * `PATH` includes `%ROOT%\OCaml\bin` and `%CYGROOT%\dll` (`PATH` is semicolon-delimited)
  * `OCAMLLIB` is set to `%ROOT%\OCaml\lib`
5. From an elevated command prompt (which needs to be a fresh one, or the changes to the environment variables will not be picked up), run `build.cmd`
  * The build process will launch Cygwin setup and then a series of Cygwin terminal windows (corresponding to the number of CPUs detected) will start
  * Each of these will attempt to compile packages, if dependencies have been met
  * At the end of the build process, all the build daemons will automatically shutdown
  * A full documentation tree for OCaml and the 3rd party libraries is installed to `%ROOT%\Src\docs`
  * Logs and scripts are placed in `%ROOT%\Src\build`:
    * `build`, `build-package` and `packages` are the Unix portion of the build system
    * `.complete` and `*.stamp` are cookies left over from the build process
    * `package.Foo` is the output from successfully building package Foo
    * `failure.Foo` is the output from failing to build the package Foo
    * `blocked.Foo` indicates that package Foo could not be built because a dependency failed to build 