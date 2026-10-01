/* REXX */

/*
trace ?i
*/
trace ?i

CRLF ='0D0A'X
ETC = value('ETC',,'OS2ENVIRONMENT')

Call rxfuncadd 'SysLoadFuncs','REXXUTIL','SysLoadFuncs'
Call SysIni 'BOTH','FolderWorkareaRunningObjects','ALL:','DESK'
Desktop = desk.1

OldBoot = Q
NewBoot = SysBootDrive()
doANPM  = 'ANPN import from h:\tsm\ArcaOSmigrate.yum'
parse upper arg args
do while args ª= ''
   parse var args arg args
   select
      when arg~abbrev('-') | arg~abbrev('/') then do
         opt = arg~delstr(1,1)
         select
            when opt = 'REANPM' | opt ='RESUMEANPM' then do
               doANPM = 'Resuming ANPM after boot'
               signal REANPM
               end
            when opt = TRACE then
               trace ?i
            otherwise do
               say arg 'is an invalid option'
               exit
               end
            end
         end
      when arg~length = 1 | arg~length = 2 then
      if SysDriveInfo(arg) > '' then
         oldboot = arg~left(2,':')
      else do
         say 'Invalid drive' arg
         exit
         end
      otherwise do
         say 'Invalid parameter' arg
         say 'Did you mean -'arg'?'
         exit
         end
      end
   end


'ln -s' newboot'\MPTN\ETC\resolv2' newboot'\etc\resolv.conf'


/* Load Firefox DLLs in high memory */
newboot'\SYS\APPS\ANTURBO\TURBOSETUP.CMD'


Object      = '<WP_DESKTOP>'
SetupString = 'OPEN=SETTINGS;'
call SetObjectData
call pause 'Select Desktop tab and check',                        ,
           'Select Startup tab and check'                         ,
           'Click Create ArcaOS Desktop Startup folder'


Object      = '<WP_DRIVES>'
SetupString = 'OPEN=SETTINGS;'
call SetObjectData 'Select View tab and check',        ,
                   '  Show full path',                 ,
                   '  Keep original title',            ,
                   'Select Drive Icons tab and check', ,
                   '  Drive letter before'
call pause


say 'Check Styler Shutdown tab'
say 'Check Styler Reboot tab'
newboot'\sys\apps\styler\styler.exe S'


stat = SysOpenObject('<XWP_WPS>', 'RUNNING', 'FALSE')
say 'SysOpenObject returned' stat 'for <XWP_WPS>'
call pause 'Select Folder Views tab and check',    ,
           '  Show full path',                     ,
           '  Keep original title'

Location    = '<XWP_STARTUP>'
Object      = 'H:\Utility\substsetup.cmd'
call CreateShadow


START 'H:\TSPF12\TSPF32' newboot'\sys\apps\4OS2\4start.cmd /i Up4START'
call pause 'Running H:\TSPF12\Up4START.spf against' newboot'\sys\apps\4OS2\4start.cmd'

START 'H:\TSPF12\TSPF32' newboot'\config.sys /i Upconfig'
call pause 'Running H:\TSPF12\Upconfig.spf against' newboot'\config.sys'

echo on

/*
   WPS info for IBM Developer's Toolkit is at e:\var\toolkit.objects.classes
   WPS info for Desktop is at g:\var\Desktop.objects.classes
*/

/* find most recent gotcha */
if SysFileTree('H:\Vendors\ArcaNoae\Gotcha-*.wpi', Files., 'FL') = 0 then do
   highdate = ''
   do i=1 to files.0
      parse var files.i Mdate Mtime Size Attributes Filename
      if Mdate > highdate then do
         highdate = Mdate
         highfile = Filename
         end
      end
   if highdate ª= '' then do
      NewBoot'\sys\install\WARPIN\warpin' highfile
      end
   end
else
   say 'SysFileTree(H:\Vendors\ArcaNoae\Gotcha-*.wpi, Files., ''FL'') failed'

/* find most recent testlog */
/* Don't nned to run latest.testlog.cmd bcause testlog now in repository
if SysFileTree('H:\Vendors\ArcaNoae\testlog-*.exe', Files., 'FL') = 0 then do
   highdate = ''
   do i=1 to files.0
      parse var files.i Mdate Mtime Size Attributes Filename
      if Mdate > highdate then do
         highdate = Mdate
         highfile = Filename
         end
      end
   if highdate ª= '' then
      highfile
   end
else
   say 'SysFileTree(H:\Vendors\ArcaNoae\testlog-*.exe, Files., ''FL'') failed'
*/

/* copy definitions of cloned repositories */
/*
copy oldboot'\etc\yum\repos.d\\*-clone.repo' newboot'\etc\yum\repos.d\'
*/

/* Install RPM packages */
/* 'yum install netlabs-rel' */
/* ANPN import from h:\tsm\ArcaOSmigrate.yum */

REANPM:
/* Add repositories from https://www.arcanoae.com/wiki/anpm/ */
stat = SysOpenObject('<WP_ANPM>', 'RUNNING', 'FALSE')
call pause 'SysOpenObject returned' stat 'for <WP_ANPM>',                 ,
           'Install repository Arcanoae-rel'                              ,
                   'https://repos.arcanoae.com/release/$releasever/'      ,
                   'no authentification',                                 ,
           'Install repository Arcanoae-arcaos'                           ,
                   'https://repos.arcanoae.com/arcaos/$releasever/'       ,
                   'authentification',                                    ,
           'Install repository Arcanoa-sub'                               ,
                   'https://repos.arcanoae.com/subscription/$releasever/' ,
                   'authentification',                                    ,
           'Install repository Arcanoae-rel-wpi'                          ,
                   'https://repos.arcanoae.com/wpi/release/'              ,
                   'no authentification',                                 ,
           'Install repository Arcanoae-arcaos-wpi'                       ,
                   'https://repos.arcanoae.com/wpi/arcaos/'               ,
                   'authentification',                                    ,
           'Install repository Arcanoa-sub-wpi'                           ,
                   'https://repos.arcanoae.com/wpi/subscription/'         ,
                   'authentification',                                    ,
           'Install netlabs-exp',                                         ,
           'Disable the Netlabs experimental repository',                 ,
           doANPM

hotserve = '/H /O /T /S /E /R /V'

/* Copy Firefox profile */
FFold = ''
FFnew = ''

if SysFileTree(oldboot'\Home\Mozilla\Firefox\Profiles\*', FFo., 'DO') = 0 then do
   select
      when FFo.0 = 0 then
         say 'No FireFox profile found on' oldboot
      when FFo.0 = 1 then do
         say 'old profile' FFo.1
         FFold = FFo.1
         end
      otherwise do
         say FFo.0 'Firefox profiles found on' oldboot
         do i=i to FFo.0
            say ' ' FFo.i
            end
         end
      end
   end
else
   say 'SysFileTree('oldboot'\Home\Mozilla\Firefox\Profiles\*, FFO., ''DO'') failed'

if SysFileTree(newboot'\Home\Mozilla\Firefox\Profiles\*', ffn., 'DO') = 0 then do
   select
      when ffn.0 = 0 then
         say 'No FireFox profile found on' newboot
      when ffn.0 = 1 then do
         say 'new profile' ffn.1
         FFnew = FFn.1
         end
      otherwise do
         say ffn.0 'Firefox profiles found on' newboot
         do i=i to ffn.0
            say ' ' ffn.i
            end
         end
      end
   end
else
   say 'SysFileTree('newboot'\Home\Mozilla\Firefox\Profiles\*, FFN., ''DO'') failed'

select
  when FFold = '' then
     say 'No Firefix profile to copy'
  when FFnew = '' then do
     say 'I haven''t figured out how to clone the profile'
     /*
     XCOPY oldboot'\Home\Mozilla\Firefox\Profiles'  ,
           newboot'\Home\Mozilla\Firefox\Profiles\' ,
           hotserve
     */
     end
  otherwise
     say 'Firefox profile allready exists'
  end

/* Add code to update prefs.js with
   user_pref("browser.bookmarks.autoExportHTML", true);
*/

/* Copy Thunderbird profile */
TBold = ''
TBnew = ''

if SysFileTree(oldboot'\Home\Thunderbird\Profiles\*', TBo., 'DO') = 0 then do
   select
      when TBo.0 = 0 then
         say 'No Thunderbird profile found on' oldboot
      when TBo.0 = 1 then do
         say 'old profile' TBo.1
         TBold = TBo.1
         end
      otherwise do
         say TBo.0 'Thunderbird profiles found on' oldboot
         do i=i to TBo.0
            say ' ' TBo.i
            end
         end
      end
   end
else
   say 'SysFileTree('oldboot'\Home\Thunderbird\Profiles\*, TBo., ''DO'') failed'

if SysFileTree(newboot'\Home\Thunderbird\Profiles\*', TBn., 'DO') = 0 then do
   select
      when TBn.0 = 0 then
         say 'No Thunderbird profile found on' newboot
      when TBn.0 = 1 then do
         say 'old profile' TBn.1
         TBnew = TBn.1
         end
      otherwise do
         say TBn.0 'Thunderbird profiles found on' newboot
         do i=i to TBn.0
            say ' ' TBn.i
            end
         end
      end
   end
else
   say 'SysFileTree('newboot'\Home\Thunderbird\Profiles\*, TBN., ''DO'') failed'

/* Copy INI data */

if SysIni(OldBoot'\OS2\OS2.INI', 'Fax', 'ALL:', 'FAX.') = 'ERROR:' then
   say 'Unable to find application Fax in' OldBoot'\OS2\OS2.INI'
else do i=1 to Fax.0
   value = SysIni(OldBoot'\OS2\OS2.INI', 'Fax', Fax.i)
   call SysIni USER, 'Fax', Fax.i, value
   end

if SysIni(OldBoot'\OS2\OS2.INI', 'GFC', 'ALL:', 'GFC.') = 'ERROR:' then
   say 'Unable to find application GFC in' OldBoot'\OS2\OS2.INI'
else do i=1 to GFC.0
   value = SysIni(OldBoot'\OS2\OS2.INI', 'GFC', GFC.i)
   call SysIni USER, 'GFC', GFC.i, value
   end

if SysIni(OldBoot'\OS2\OS2.INI', 'GTU.GLOBAL', 'ALL:', 'GTU.') = 'ERROR:' then
   say 'Unable to find application GTU.GLOBAL in' OldBoot'\OS2\OS2.INI'
else do i=1 to GTU.0
   value = SysIni(OldBoot'\OS2\OS2.INI', 'GTU.GLOBAL', GTU.i)
   call SysIni USER, 'GTU.GLOBAL', GTU.i, value
   end

if SysIni(OldBoot'\OS2\OS2.INI', 'GTU.OPTIMIZE', 'ALL:', 'GTU.') = 'ERROR:' then
   say 'Unable to find application GTU.OPTIMIZE in' OldBoot'\OS2\OS2.INI'
else do i=1 to GTU.0
   value = SysIni(OldBoot'\OS2\OS2.INI', 'GTU.OPTIMIZE', GTU.i)
   call SysIni USER, 'GTU.OPTIMIZE', GTU.i, value
   end

if SysIni(OldBoot'\OS2\OS2.INI', 'GTU.SENTRY', 'ALL:', 'GTU.') = 'ERROR:' then
   say 'Unable to find application GTU.SENTRY in' OldBoot'\OS2\OS2.INI'
else do i=1 to GTU.0
   value = SysIni(OldBoot'\OS2\OS2.INI', 'GTU.SENTRY', GTU.i)
   call SysIni USER, 'GTU.SENTRY', GTU.i, value
   end


if SysIni(OldBoot'\OS2\OS2.INI', 'ViewAll', 'ALL:', 'VIEWALL.') = 'ERROR:' then
   say 'Unable to find application ViewAll in' OldBoot'\OS2\OS2.INI'
else do i=1 to VIEWALL.0
   value = SysIni(OldBoot'\OS2\OS2.INI', 'VIEWALL', VIEWALL.i)
   call SysIni USER, 'VIEWALL', VIEWALL.i, value
   end

backupdir = SysIni(OldBoot'\OS2\OS2.INI', 'Uni Maintenance', 'Port Backup Default Directory')
call SysIni USER,'Uni Maintenance', 'Port Backup Default Directory', backupdir

/* Set kLIBC path mappings
call SysIni ETC'\KLIBCFG.INI', REWRITE, alias, truepath
*/
call SysIni ETC'\KLIBCFG.INI', REWRITE, '/drives/H', 'H:\'
call SysIni ETC'\KLIBCFG.INI', REWRITE, '/drives/J', 'J:\'
call SysIni ETC'\KLIBCFG.INI', REWRITE, '/drives/K', 'K:\'

/* Install 3rd party software */
SET BEGINLIBPATH'='NewBoot'\sys\install\WARPIN'
'H:\Vendors\DFSEE\dfsee_os2_wpi'
copy OldBoot'\SYS\APPS\DFSEE\BIN\DFSEE.KEY'                               ,
     NewBoot'\SYS\APPS\DFSEE\BIN\DFSEE.KEY'

NewBoot'\sys\install\WARPIN\warpin H:\Vendors\JAREAD\Filestar\fs_30500.wpi'

START 'H:\Vendors\GammaTech\GTU40\GTINST.EXE'
call pause 'Select Install Product'

/* find most recent OpenOffice */
if SysFileTree('H:\Vendors\Bitwise\AOO-*-GA-BASE-EN-US.wpi', Files., 'FL') = 0 then do
   highdate = ''
   do i=1 to files.0
      parse var files.i Mdate Mtime Size Attributes Filename
      if Mdate > highdate then do
         highdate = Mdate
         highfile = Filename
         end
      end
   if highdate ª= '' then do
      NewBoot'\sys\install\WARPIN\warpin' highfile
      end
   end
else
   say 'SysFileTree(H:\Vendors\Bitwise\AOO-*-GA-BASE-EN-US.wpi, Files., ''FL'') failed'

NewBoot'\sys\install\WARPIN\warpin H:\Vendors\JAREAD\Unimaint\um_51032.wpi'

/* call 'h:\Vendors\STARDOCK\GC2\INSTALL.CMD' */

copy OldBoot'\MPTN\ETC\TCPOS2.INI'                  ETC'\TCPOS2.INI'
md   ETC'\WHOIS'
copy OldBoot'\MPTN\ETC\WHOIS\*'                     ETC'\WHOIS'


Location    = "<WP_INSTREMFOLDER>"
Title       = "Arca Noae Package Manager (debug)"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\SYS\APPS\ANPM\ANPM.EXE;'              || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=/DEB;'                                       || ,
              'TITLE=Arca Noae Package Manager (debug);'               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_ANPM_DEBUG>;'
call CreateObject

Location    = "<WP_CONFIG>"
Title       = "Arca Noae Package Manager (debug)"
Class       = "WPShadow"
SetupString = 'SHADOWID=<WP_ANPM_DEBUG>;'                              || ,
              'TITLE=Arca Noae Package Manager (debug);'               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<SHADOW_ANPM_DEBUG>;'
call CreateObject

/* Create DFSEEE interactive windows of three sizes */

Location    = "<DFSEE_FOLDER>"
Title       = "DFSee^Interactive"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\SYS\APPS\DFSEE\BIN\DFSEE.CMD;'        || ,
              'STARTUPDIR='newboot'\SYS\APPS\DFSEE\BIN;'               || ,
              'PROGTYPE=WINDOWABLEVIO;'                                || ,
              'PARAMETERS=120 34;'                                     || ,
              'TITLE=DFSee^Interactive;'                               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<DFSEE_INTERACTIVE>;'
call CreateObject

Location    = "<DFSEE_FOLDER>"
Title       = "DFSee^Large Window"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\SYS\APPS\DFSEE\BIN\DFSEE.CMD;'        || ,
              'STARTUPDIR='newboot'\SYS\APPS\DFSEE\BIN;'               || ,
              'PARAMETERS=92 39;'                                      || ,
              'TITLE=DFSee^Large Window;'                              || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<DFSEE_LARGEWINDOW>;'
call CreateObject

Location    = "<DFSEE_FOLDER>"
Title       = "DFSee^Huge Window"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\SYS\APPS\DFSEE\BIN\DFSEE.CMD;'        || ,
              'STARTUPDIR='newboot'\SYS\APPS\DFSEE\BIN;'               || ,
              'PARAMETERS=128 44;'                                     || ,
              'TITLE=DFSee^Huge Window;'                               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<DFSEE_HUGEWINDOW>;'
call CreateObject

Location    = "<DFSEE_FOLDER>"
Title       = "DFSee^Huge Window with log"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\SYS\APPS\DFSEE\BIN\DFSEE.CMD;'        || ,
              'STARTUPDIR='newboot'\SYS\APPS\DFSEE\BIN;'               || ,
              'PARAMETERS=128 44 -l:$_exedir\..\log\DFS@-~;'           || ,
              'TITLE=DFSee^Huge Window with log;'                      || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<DFSEE_HUGEWINDOW_LOG>;'
call CreateObject

Object      = '<WP_OS2WIN>'
SetupString = 'PARAMETERS=/k mode 80,100;'                             || ,
              'STARTUPDIR=H:\;'
call SetObjectData

Object      = '<WP_4OS2WIN>'
SetupString = 'PARAMETERS=/k mode 80,100;'                             || ,
              'STARTUPDIR=H:\;'
call SetObjectData

tk:
/* IBM Developer's Toolkit */

Location    = '<WP_PROGRAMSFOLDER>'
Title       = 'Development'
Class       = 'WPPngFolder'
SetupString = 'OBJECTID=<WP_DEVFLDR>;'
call CreateObject

Location    = '<WP_DEVFLDR>'
Title       = "IBM Developer's Toolkit^version 4.5"
Class       = 'WPPngFolder'
SetupString = 'ICONVIEW=FLOWED,VISIBLE,NORMAL;'                        || ,
              'TREEVIEW=LINES,VISIBLE,MINI;'                           || ,
              'DEFAULTSORT=1;'                                         || ,
              'ALWAYSSORT=YES;'                                        || ,
              "TITLE=IBM Developer's Toolkit^version 4.5;"             || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT>;'
call CreateObject

Location    = '<TOOLKIT>'
Title       = 'Development Tools'
Class       = 'WPPngFolder'
SetupString = 'ICONVIEW=NONGRID,NORMAL;'                               || ,
              'TREEVIEW=LINES,VISIBLE,MINI;'                           || ,
              'DEFAULTSORT=1;'                                         || ,
              'ALWAYSSORT=YES;'                                        || ,
              'TITLE=Development Tools;'                               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_DEVTOOLS>;'
call CreateObject

/*
copy oldboot'\OS2TK45\bin\kwikinf.exe' newboot'\usr\bin\'
copy oldboot'\OS2TK45\dll\kiutil.dll'  newboot'\usr\lib\'
Location    = '<TOOLKIT_DEVTOOLS>'
Title       = 'KwikInf'
Class       = 'XWPProgram'
SetupString = 'EXENAME='newboot'\usr\bin\KWIKINF.EXE;'                 ||;
              'STARTUPDIR='newboot'\usr\bin;'                          ||;
              'PROGTYPE=PM;'                                           ||;
              'TITLE=KwikInf;'                                         ||;
              'NOPRINT=YES;'                                           ||;
              'HIDEBUTTON=DEFAULT;'                                    ||;
              'MINWIN=DEFAULT;'                                        ||;
              'CCVIEW=DEFAULT;'                                        ||;
              'DEFAULTVIEW=DEFAULT;'                                   ||;
              'OBJECTID=<TOOLKIT_DEVTOOLS_BASE_KWIKINF>;'
call CreateObject
*/

Location    = '<TOOLKIT>'
Title       = 'Toolkit Information'
Class       = 'WPPngFolder'
SetupString = 'ICONVIEW=FLOWED,VISIBLE,NORMAL;'                        || ,
              'TREEVIEW=LINES,VISIBLE,MINI;'                           || ,
              'DEFAULTSORT=1;'                                         || ,
              'ALWAYSSORT=YES;'                                        || ,
              'TITLE=Toolkit Information;'                             || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Legacy Resource Compiler^(RC16) Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=rc16.inf;'                                   || ,
              'TITLE=Legacy Resource Compiler^(RC16) Reference;'       || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_RC16>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'NMAKE32 Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=nmake32.inf;'                                || ,
              'TITLE=NMAKE32 Reference;'                               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_NMAKE32>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'C Library Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=xpg4ref.inf;'                                || ,
              'TITLE=C Library Reference;'                             || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_CLIBREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'SOM Programming Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=somref.inf;'                                 || ,
              'TITLE=SOM Programming Reference;'                       || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_SOMREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'SOM Programming Guide'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=somguide.inf;'                               || ,
              'TITLE=SOM Programming Guide;'                           || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_SOMGDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'TCP/IP Programming Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=tcppr.inf;'                                  || ,
              'TITLE=TCP/IP Programming Reference;'                    || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_TCPIPREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'OS/2 Debugging Handbook'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'TITLE=OS/2 Debugging Handbook;'                         || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_DEBUGREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'OS/2 Programming^Guide and Reference Addendum'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=addendum.inf;'                               || ,
              'TITLE=OS/2 Programming^Guide and Reference Addendum;'   || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_ADDENDUM>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Workplace Shell^Programming Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=WPS1.INF+WPS2.INF+WPS3.INF;'                 || ,
              'TITLE=Workplace Shell^Programming Reference;'           || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_WPSREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Workplace Shell^Programming Guide'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=wpsguide.inf;'                               || ,
              'TITLE=Workplace Shell^Programming Guide;'               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_WPSGDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Multimedia Subsystem^Programming Guide'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=mmsspg.inf;'                                 || ,
              'TITLE=Multimedia Subsystem^Programming Guide;'          || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_MMSUBGDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Multimedia Programming^Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=MMREF1.INF+MMREF2.INF+MMREF3.INF;'           || ,
              'TITLE=Multimedia Programming^Reference;'                || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_MMREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Multimedia Application^Programming Guide'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=mmapg.inf;'                                  || ,
              'TITLE=Multimedia Application^Programming Guide;'        || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_MMAPPGDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'IPF Programming^Guide and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=ipfref.inf;'                                 || ,
              'TITLE=IPF Programming^Guide and Reference;'             || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_IPFGDEREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Bidirectional Language^Programming Guide'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=pmbdtech.inf;'                               || ,
              'TITLE=Bidirectional Language^Programming Guide;'        || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_BIDIGDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'rxstring.doc'
Class       = 'WPShadow'
SetupString = 'SHADOWID='newboot'\usr\share\os2\book\RXSTRING.DOC;'    || ,
              'TITLE=rxstring.doc;'                                    || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_RXSTRING>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Control Program Programming^Guide and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=CP1.INF+CP2.INF+CP3.INF;'                    || ,
              'TITLE=Control Program Programming^Guide and Reference;' || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_CPGDEREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Windows Sockets'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=winsoc11.inf;'                               || ,
              'TITLE=Windows Sockets;'                                 || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_WINSOCK>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Presentation Manager Programming^Guide and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                           || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'                    || ,
              'PROGTYPE=PM;'                                                || ,
              'PARAMETERS=PM1.INF+PM2.INF+PM3.INF+PM4.INF+PM5.INF;'         || ,
              'TITLE=Presentation Manager Programming^Guide and Reference;' || ,
              'NOPRINT=YES;'                                                || ,
              'HIDEBUTTON=DEFAULT;'                                         || ,
              'MINWIN=DEFAULT;'                                             || ,
              'CCVIEW=DEFAULT;'                                             || ,
              'DEFAULTVIEW=DEFAULT;'                                        || ,
              'OBJECTID=<TOOLKIT_INFO_PMGDEREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'OpenGL Programming^Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=oglbase.inf;'                                || ,
              'TITLE=OpenGL Programming^Reference;'                    || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_OGLBASE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Open32 Programming Guide^and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=open32.inf;'                                 || ,
              'TITLE=Open32 Programming Guide^and Reference;'          || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_DAXPROG>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Object REXX Programming Guide'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=rexxpg.inf;'                                 || ,
              'TITLE=Object REXX Programming Guide;'                   || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_REXXPG>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Tools Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=toolsref.inf;'                               || ,
              'TITLE=Tools Reference;'                                 || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_TOOLSREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'IBM OS/2 Server Family^Programming Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=srvfpgr.inf;'                                || ,
              'TITLE=IBM OS/2 Server Family^Programming Reference;'    || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_LANSERVREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'GPI Guide^and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=GPI1.INF+GPI2.INF+GPI3.INF+GPI4.INF;'        || ,
              'TITLE=GPI Guide^and Reference;'                         || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_GPIGDEREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = "DPI Programmer's Guide"
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=dpil1mst.inf;'                               || ,
              "TITLE=DPI Programmer's Guide;"                          || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_DPIGUIDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = "DMI Programmer's Guide"
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=dnal1mst.inf;'                               || ,
              "TITLE=DMI Programmer's Guide;"                          || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_DMIGUIDE>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'ALP Programming^Guide and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=alpref.inf;'                                 || ,
              'TITLE=ALP Programming^Guide and Reference;'             || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_ALPREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Problem Determination^Guide and Reference'
Class       = 'XWPProgram'
SetupString = 'EXENAME=VIEW.EXE;'                                      || ,
              'STARTUPDIR='newboot'\usr\share\os2\book;'               || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=pdguide.inf;'                                || ,
              'TITLE=Problem Determination^Guide and Reference;'       || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<TOOLKIT_INFO_PROBDET>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'LX Module Format Specification'
Class       = 'WPUrl'
SetupString = 'TITLE=LX Module Format Specification;'                    || ,
              'URL=file:///'newboot'\OS2TK45\book\lxref.htm;'            || ,
              'DEFAULTBROWSER='newboot'\PROGRAMS\Firefox\firefox!k.exe;' || ,
              'DEFAULTWORKINGDIR='newboot'\PROGRAMS\Firefox;'            || ,
              'HIDEBUTTON=DEFAULT;'                                      || ,
              'MINWIN=DEFAULT;'                                          || ,
              'CCVIEW=DEFAULT;'                                          || ,
              'DEFAULTVIEW=ICON;'                                        || ,
              'OBJECTID=<TOOLKIT_INFO_LXREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Object Module Format Specification'
Class       = 'WPUrl'
SetupString = 'TITLE=Object Module Format Specification;'                || ,
              'URL=file:///'newboot'\OS2TK45\book\omfref.htm;'           || ,
              'DEFAULTBROWSER='newboot'\PROGRAMS\Firefox\firefox!k.exe;' || ,
              'DEFAULTWORKINGDIR='newboot'\PROGRAMS\Firefox;'            || ,
              'HIDEBUTTON=DEFAULT;'                                      || ,
              'MINWIN=DEFAULT;'                                          || ,
              'CCVIEW=DEFAULT;'                                          || ,
              'DEFAULTVIEW=ICON;'                                        || ,
              'OBJECTID=<TOOLKIT_INFO_OMFREF>;'
call CreateObject

Location    = '<TOOLKIT_INFO>'
Title       = 'Unicode Programming Reference'
Class       = 'WPUrl'
SetupString = 'TITLE=Unicode Programming Reference;'                     || ,
              'URL=file:///'newboot'\OS2TK45\book\uniapi.htm;'           || ,
              'DEFAULTBROWSER='newboot'\PROGRAMS\Firefox\firefox!k.exe;' || ,
              'DEFAULTWORKINGDIR='newboot'\PROGRAMS\Firefox;'            || ,
              'HIDEBUTTON=DEFAULT;'                                      || ,
              'MINWIN=DEFAULT;'                                          || ,
              'CCVIEW=DEFAULT;'                                          || ,
              'DEFAULTVIEW=ICON;'                                        || ,
              'OBJECTID=<TOOLKIT_INFO_UNICODE>;'
call CreateObject


Location    = '<WP_DESKTOP>'
Title       = 'Family Tree 1.2f'
Class       = 'XWPProgram'
SetupString = 'OBJECTID=<FTREE>;'                                      || ,
              'PROGTYPE=PM;'                                           || ,
              'EXENAME=H:\UTILITY\FTREE\FTREE.EXE;'                    || ,
              'PARAMETERS=metz.fam;'                                   || ,
              'STARTUPDIR=H:\UTILITY\FTREE;'                           || ,
              'ASSOCFILTER=*.FAM;'
call CreateObject

   if setlocal() then do
      'SET BEGINLIBPATH='newboot'\Programs\firefox'
      newboot
      'CD' newboot'\Programs\firefox'
      /* First launch only creates the new profile skeleton; Firefox must
         be closed again before copying into it, since the profile is
         locked while running. */
      'START' newboot'\Programs\firefox\firefox.exe'
      call pause 'Close Firefox once the new profile window has loaded,', ,
                 'so bookmarks and open tabs can be copied in.'
      /* Copy bookmarks+history and the open-tabs session directly --
         no HTML export/import needed. FFold/FFnew are the old/new
         profile directory names found above. */
      copy oldboot'\Home\Mozilla\Firefox\Profiles\'FFold'\places.sqlite' ,
           newboot'\Home\Mozilla\Firefox\Profiles\'FFnew'\places.sqlite'
      copy oldboot'\Home\Mozilla\Firefox\Profiles\'FFold'\sessionstore-backups\recovery.jsonlz4' ,
           newboot'\Home\Mozilla\Firefox\Profiles\'FFnew'\sessionstore-backups\recovery.jsonlz4'
      'START' newboot'\Programs\firefox\firefox.exe about:preferences'
      call pause 'General:',                                                 ,
                 '    Click Downloads Always ask me where to save files',    ,
                 'Search:',                                                  ,
                 '    Default: DuckDuckGo',                                  ,
                 'Content:',                                                 ,
                 '    Languages: add Hebrew as last',                        ,
                 'Privacy:',                                                 ,
                 "    Tracking: don't track",                                ,
                 'Advanced:',                                                ,
                 '    Accessability:',                                       ,
                 '        cursor keys',                                      ,
                 '        warn'
      stat = endlocal()
      end
   else do
      say 'Unable to save environment'
      exit
      end
/*
   q:\Programs\firefox\firefox.exe
   about:config
   browser.bookmarks.autoExportHTML
*/

Location    = '<WP_DESKTOP>'
Title       = 'Galactic Civilizations 2'
Class       = 'WPPngFolder'
SetupString = 'OBJECTID=<GCFOLDER>;'                                   || ,
              'ICONRESOURCE=1,H:\GAMES\GALCIV\GALCIV.EXE;'

if CreateObject() then do
   Location    = '<GCFOLDER>'
   Title       = 'Galactic Civilizations'
   Class       = 'XWPProgram'
   SetupString = 'OBJECTID=<GCPROGRAM>;'                               || ,
                 'PROGTYPE=PM;'                                        || ,
                 'EXENAME=H:\GAMES\GALCIV\GALCIV.EXE;'                 || ,
                 'STARTUPDIR=H:\GAMES\GALCIV;'                         || ,
                 'ICONRESOURCE=1,H:\GAMES\GALCIV\GALCIV.EXE'
   call CreateObject

   Location    = '<GCFOLDER>'
   Title       = 'GalCiv: The Movie'
   Class       = 'XWPProgram'
   SetupString = 'PROGTYPE=PM;'                                        || ,
                 'EXENAME=MPPM.EXE;'                                   || ,
                 'PARAMETERS=H:\Vendors\STARDOCK\GC2\GCMOVIE.AVI;'     || ,
                 'ICONRESOURCE=1,H:\GAMES\GALCIV\GALCIV.EXE'
   call CreateObject

   Location    = '<WP_GAMES>'
   Object      = '<GCPROGRAM>'
   call CreateShadow

   if setlocal() then do
      'SET BEGINLIBPATH=H:\GAMES\GALCIV'
      'H:'
      'CD \GAMES\GALCIV\GALCIV.EXE'
      if SysOpenObject('<GCPROGRAM>', 'RUNNING', 'FALSE') then do
         START newboot'\PROGRAMS\LUCIDE\LUCIDE.EXE'                             ,
               'H:\Games\GalCiv\codes.pdf'
         call pause 'Select key from codes.pdf'
         end
      else
         say 'Unable to launch Galactic Civilisation'
      stat = endlocal()
      end
   else do
      say 'Unable to save environment'
      exit
      end
   end


Location    = '<WP_DESKTOP>'
Title       = 'GFC'
Class       = 'XWPProgram'
SetupString = 'PROGTYPE=PM;'                                           || ,
              'EXENAME=H:\PRODTOOL\OS2GFC\GFC.EXE;'                    || ,
              'STARTUPDIR=H:\PRODTOOL\OS2GFC;'
call CreateObject


Object      = '<gtu 4.0>'
SetupString = 'ICONFILE='NewBoot'\GTU40\GAMMA.ICO;'
call SetObjectData


/* Install IBMWORKS */

/*
cdd 'H:\vendors\IBM\BONTRIAL\IBMBON'
PATH '%PATH%'NewBoot'\OS2\INSTALL;'
SET BEGINLIBPATH'='NewBoot'\OS2\INSTALL'
MD '/s' Newboot':\ECS\INSTALL\RSP'
ibmworks
*/

/* Copy IBMWORKS            */
MD '/s' NewBoot'\PROGRAMS\ibmworks\DATA'
copy OldBoot'\PROGRAMS\ibmworks\DATA\ /B'                             ,
     NewBoot'\PROGRAMS\ibmworks\DATA\'
xcopy '/h /o /t /s /e /r /v'              OldBoot'\PROGRAMS\ibmworks' ,
                                          NewBoot'\PROGRAMS\ibmworks\'
copy                                      OldBoot'\OS2\DLL\fpw*'      ,
                                          NewBoot'\OS2\DLL\'
copy                                      OldBoot'\OS2\DLL\ien*'      ,
                                          NewBoot'\OS2\DLL\'

Location    = "<WP_READMEFOLDER>"
Title       = "IBM Works^ReadMe"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\IBMWORKS.EXE;'      || ,
              'PARAMETERS='newboot'\PROGRAMS\ibmworks\readme;'         || ,
              'TITLE=IBM Works^ReadMe;'                                || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWO_README>;'
call CreateObject

Location    = "<WP_APPSFOLDER>"
Title       = "IBM Works"
Class       = "WPFolder"
SetupString = 'ICONVIEW=NONGRID,NORMAL;'                               || ,
              'TREEVIEW=LINES,VISIBLE,MINI;'                           || ,
              'DEFAULTSORT=-2;'                                        || ,
              'ALWAYSSORT=YES;'                                        || ,
              'TITLE=IBM Works;'                                       || ,
              'ICONVIEWPOS=14,59,80,14;'                               || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWO_FOLD>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "FootPrint Catalyst"
Class       = "FpwCatalyst"
SetupString = 'TITLE=FootPrint Catalyst;'                              || ,
              'NOPRINT=YES;'                                           || ,
              'NOTVISIBLE=YES;'                                        || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<FPW_CATALYST>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Appointments"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-M;'                                         || ,
              'TITLE=Appointments;'                                    || ,
              'NOPRINT=YES;'                                           || ,
              'HELPPANEL=12000;'                                       || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMA_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Phone/Address Book"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-P;'                                         || ,
              'TITLE=Phone/Address Book;'                              || ,
              'NOPRINT=YES;'                                           || ,
              'HELPPANEL=13000;'                                       || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMP_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Notepad"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-N;'                                         || ,
              'TITLE=Notepad;'                                         || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMN_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Planner"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-G;'                                         || ,
              'TITLE=Planner;'                                         || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMG_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "To Do List"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-T;'                                         || ,
              'TITLE=To Do List;'                                      || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMT_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Year Calendar"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-Y;'                                         || ,
              'TITLE=Year Calendar;'                                   || ,
              'NOPRINT=YES;'                                           || ,
              'HELPPANEL=11210;'                                       || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMY_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Event Monitor"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWMON.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'TITLE=Event Monitor;'                                   || ,
              'NOPRINT=YES;'                                           || ,
              'HELPPANEL=10100;'                                       || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIME_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "PIM Preference"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\FPWPIM.EXE;'        || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=-S;'                                         || ,
              'TITLE=PIM Preference;'                                  || ,
              'NOPRINT=YES;'                                           || ,
              'HELPPANEL=17000;'                                       || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWPIMS_EXE>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "Samples"
Class       = "WPShadow"
SetupString = 'SHADOWID='newboot'\PROGRAMS\IBMWORKS\SAMPLES;'          || ,
              'TITLE=Samples;'                                         || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWO_SAMP_FOLD>;'
call CreateObject

Location    = "<WP_FPWO_FOLD>"
Title       = "IBM Works"
Class       = "WPProgram"
SetupString = 'EXENAME='newboot'\PROGRAMS\IBMWORKS\IBMWORKS.EXE;'      || ,
              'PROGTYPE=PM;'                                           || ,
              'TITLE=IBM Works;'                                       || ,
              'NOPRINT=YES;'                                           || ,
              'HELPPANEL=1;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=YES;'                                            || ,
              'DEFAULTVIEW=DEFAULT;'                                   || ,
              'OBJECTID=<WP_FPWO_EXE>;'
call CreateObject

/* Copy IBMWORKS Appointments to Startup folder */
Location    = '<WP_START>'
Object      = '<WP_FPWPIMA_EXE>'
call CopyObject


incharge:
Location    = '<WP_PROGRAMSFOLDER>'
Title       = 'In Charge'
Class       = 'XWPProgram'
SetupString = 'OBJECTID=<WP_HINCHARGESFF>;'                            || ,
              'PROGTYPE=PM;'                                           || ,
              'EXENAME=H:\INCHARGE\SFF.EXE;'                           || ,
              'STARTUPDIR=H:\INCHARGE;'                                || ,
              'ICONFILE=H:\INCHARGE\DOLLR01.ICO;'
call CreateObject


/* Add links to information folder */
Location = '<WP_ASSISTANCE>'
Object   = newboot'\OS2\BOOK'
call CreateShadow

Object   = newboot'\sys\book'
call CreateShadow


Location    = '<WP_DESKTOP>'
Title       = 'Library Reader/2'
Class       = 'WPPngFolder'
SetupString = 'OBJECTID=<EPALRFOLDER-ENU>;'                            || ,
              'ICONFILE=H:\READIBM2\EPAREAD2.ICO;'
if CreateObject() then do
   Location    = '<EPALRFOLDER-ENU>'
   Title       = 'BookManager Library Reader/2 User Guide'
   Class       = 'XWPProgram'
   SetupString = 'OBJECTID=<EPALRPUB2-ENU>;'                           || ,
                 'PROGTYPE=PM;'                                        || ,
                 'EXENAME=H:\READIBM2\EPAIBM0.EXE;'                    || ,
                 'PARAMETERS=M:\BOOKS\EPA3LM03.BOO;'                   || ,
                 'STARTUPDIR=H:\READIBM2;'                             || ,
                 'ICONFILE=H:\READIBM2\PRODMANU.ICO;'
   call CreateObject

   Location    = '<EPALRFOLDER-ENU>'
   Title       = 'Installation Utility'
   Class       = 'XWPProgram'
   SetupString = 'OBJECTID=<EPALRINSTS-ENU>;'                                                   || ,
                 'PROGTYPE=PM;'                                                                 || ,
                 'EXENAME=CMD.EXE;'                                                             || ,
                 'PARAMETERS=/C H:\readibm2\EPFINSTS.EXE /C:H:\readibm2\epal2enu.icf /O:DRIVE;' || ,
                 'STARTUPDIR=H:\READIBM2;'                                                      || ,
                 'ICONFILE=H:\READIBM2\epfiicis.ico;'
   call CreateObject

   /* READIBM2.CMD will isolate the SET statements in order to
      not mess up VIEWALL                                        */
   Location    = '<EPALRFOLDER-ENU>'
   Title       = 'Library Reader/2'
   Class       = 'XWPProgram'
   SetupString = 'OBJECTID=<EPALREXE-ENU>;'                                                     || ,
                 'PROGTYPE=PM;'                                                                 || ,
                 'EXENAME=CMD.EXE;'                                                             || ,
                 'PARAMETERS=/C H:\readibm2\EPFINSTS.EXE /C:H:\readibm2\epal2enu.icf /O:DRIVE;' || ,
                 'STARTUPDIR=H:\READIBM2;'                                                      || ,
                 'ICONRESOURCE=1,H:\READIBM2\READIBM.EXE;'
   call CreateObject
   end


Location    = '<WP_DESKTOP>'
Title       = 'MR/2 ICE Beta 10'
Class       = 'WPPngFolder'
SetupString = 'OBJECTID=<MR2_BETA_FOLDER>;'                            || ,
              'ICONRESOURCE=1,I:\COMM\MAIL\MR2ICE\MR2I.EXE;'

if CreateObject() then do
   Location    = '<MR2_BETA_FOLDER>'
   Title       = 'MR/2 ICE Beta 10'
   Class       = 'XWPProgram'
   SetupString = 'OBJECTID=<MR2_BETA_EXE>;'                            || ,
                 'PROGTYPE=PM;'                                        || ,
                 'EXENAME=I:\COMM\MAIL\MR2ICE\MR2I.EXE;'               || ,
                 'PARAMETERS=/s /sn;'                                  || ,
                 'STARTUPDIR=I:\COMM\MAIL\MR2ICE;'
   call CreateObject

   Location    = '<XWP_STARTUP>'
   Object      = '<MR2_BETA_EXE>'
   call CopyObject

   Location    = '<WP_PROMPTS>'
   Title       = 'MR/2 ICE beta window'
   Class       = 'XWPProgram'
   SetupString = 'PROGTYPE=WINDOWABLEVIO;'                             || ,
                 'EXENAME=*;'                                          || ,
                 'PARAMETERS=/K MODE 80,25 & mr2idump c;'              || ,
                 'STARTUPDIR=I:\COMM\MAIL\MR2ICE;'                     || ,
                 'ICONRESOURCE=1,I:\COMM\MAIL\MR2ICE\MR2I.EXE;'
   call CreateObject
   end

/*
NewBoot'\programs\OpenOffice.org.3\associations.cmd [boot]' NewBoot'\programs\OpenOffice.org.3'
NewBoot'\programs\OpenOffice.org.3\program\register.cmd [boot]' NewBoot'\programs\OpenOffice.org.3'
*/
Location    = '<WP_START>'
Object      = '<AOO_QUICKSTART>'
call CreateShadow


copy OldBoot'\PROGRAMS\PERL\Perl.ico'            NewBoot'\PROGRAMS\PERL\Perl.ico'
copy OldBoot'\PROGRAMS\PERL\lib\5.10.0\perl.inf' NewBoot'\PROGRAMS\PERL\lib\5.10.0\perl.inf'

Object      = '<PERLFOLDER>'
SetupString = 'ICONFILE='NewBoot'\PROGRAMS\PERL\Perl.ico;'
call SetObjectData

Location    = '<PERLFOLDER>'
Object      = NewBoot'\PROGRAMS\PERL\lib\5.10.0\perl.inf'
call CreateShadow

md NewBoot'\OS2\DLL\FXPRINT'
copy 'H:\VENDORS\CDS\FXPRINT.DRV' NewBoot'\OS2\DLL\FXPRINT\FXPRINT.DRV'
call SysIni USER, 'PM_DEVICE_DRIVERS', 'FXPRINT', NewBoot'\OS2\DLL\FXPRINT\FXPRINT.DRV'

Location    = '<WP_PROGRAMSFOLDER>'
Title       = 'PMfax for OS/2'
Class       = 'XWPProgram'
SetupString = 'PROGTYPE=PM;'                                       || ,
              'EXENAME=I:\COMM\FAXWORKS\PMFAX.EXE;'                || ,
              'PARAMETERS=I:\comm\FaxWorks\nstall;'                || ,
              'STARTUPDIR=I:\COMM\FAXWORKS;'                       || ,
              'ASSOCFILTER=*.FAX;'                                 || ,
              'ASSOCTYPE=FxFile;'
call CreateObject

/* Virtual printer for PMfax */
call on error name whoops
Location    = "<WP_PRINTERSFOLDER>"
Title       = "FaxPrint"
Class       = "WPPrinter"
SetupString = 'QUEUENAME=FaxPrint;'                                    || ,
              'JOBDIALOGBEFOREPRINT=NO;'                               || ,
              'APPDEFAULT=YES;'                                        || ,
              'PRINTERSPECIFICFORMAT=NO;'                              || ,
              'PRINTWHILESPOOLING=YES;'                                || ,
              'QSTARTTIME=00:00;'                                      || ,
              'QSTOPTIME=00:00;'                                       || ,
              'QUEUEDRIVER=PMPRINT;'                                   || ,
              'PRINTDRIVER=FXPRINT.Fax;'                               || ,
              'PRIORITY=5;'                                            || ,
              'OUTPUTTOFILE=NO;'                                       || ,
              'PORTNAME=LPT3;'                                         || ,
              'TITLE=FaxPrint;'                                        || ,
              'NOPRINT=YES;'                                           || ,
              'HIDEBUTTON=DEFAULT;'                                    || ,
              'MINWIN=DEFAULT;'                                        || ,
              'CCVIEW=DEFAULT;'                                        || ,
              'DEFAULTVIEW=ICON;'                                      || ,
              'OBJECTID=<WPPO_FaxPrint>;'
call CreateObject
call off error

if SysOpenObject('<WP_PRINTGUIDE>','RUNNING', 'FALSE') then do
   call pause 'Desktop->Computer->Printers',                                 ,
              'Install Printer',                                             ,
              '   Install a printer using legacy drivers',                   ,
              '      Name - Fax',                                            ,
              '      Install new printer driver',                            ,
              '         Other OS/2 printer driver',                          ,
              '         Directory = H:\Vendors\CDS',                         ,
              '         Refresh',                                            ,
              '         FxPrint',                                            ,
              '      Fxprint',                                               ,
              '   LPT3',                                                     ,
              '   Create',                                                   ,
              '   No'
   end
else
   say 'Unable to launch Install Printer dialog'

/* READIBM2.CMD will isolate the SET statements in order to
   not mess up VIEWALL                                        */
Location    = '<WP_DESKTOP>'
Title       = 'READIBM - Invoke IBM Library Reader'CRLF 'with proper environment'
Class       = 'XWPProgram'
SetupString = 'PROGTYPE=WINDOWABLEVIO;'                                || ,
              'EXENAME=H:\UTILITY\READIBM2.CMD;'                       || ,
              'STARTUPDIR=H:\READIBM2;'                                || ,
              'ICONRESOURCE=1,H:\READIBM2\READIBM.EXE;'                || ,
              'ASSOCFILTER=*.BOO;'
call CreateObject

Location    = '<WP_DIALUPTOOLS>'
Title       = 'IBM Dial-in Program (SLIPPM)'
Class       = 'XWPProgram'
SetupString = 'PROGTYPE=PM;'                                           || ,
              'EXENAME=slippm.exe;'                                    || ,
              'PARAMETERS=ppp0;'
call CreateObject

/* Shutdown settings */
Location    = '<WP_CONFIG>'
Title       = 'Styler shutdown'
Class       = 'XWPProgram'
SetupString = 'EXENAME='newboot'\sys\apps\styler\styler.exe;'          || ,
              'PROGTYPE=PM;'                                           || ,
              'PARAMETERS=S;'                                          || ,
              'STARTUPDIR='newboot'\sys\apps\styler;'
call CreateObject

Location    = '<WP_DESKTOP>'
Title       = 'TSPF'
Class       = 'XWPProgram'
SetupString = 'PROGTYPE=WINDOWABLEVIO;'                                || ,
              'EXENAME=*;'                                             || ,
              'PARAMETERS=/c mode 132,50 & H:\TSPF12\TSPF32.EXE;'      || ,
              'STARTUPDIR=H:\TSPF12;'                                  || ,
              'ICONFILE=H:\TSPF12\TSPF32.ICO;'                         || ,
              'OBJECTID=<TSPF>;'
call CreateObject



Location    = '<WP_DESKTOP>'
Title       = 'VIEWALL^Online books'
Class       = 'XWPProgram'
SetupString = 'PROGTYPE=PM;'                                           || ,
              'EXENAME=H:\PRODTOOL\VIEWALL\VIEWALL.EXE;'               || ,
              'STARTUPDIR=H:\PRODTOOL\VIEWALL;'
call CreateObject


/*
              'ADDWIDGETS=classname(setup),
                          XButton(OBJECTHANDLE=object)
*/
Object      = '<XWP_XCENTER>'
SetupString = 'ADDWIDGETS=DiskFreeCondensed(),'                        || ,
                         'Sentinel(),'                                 || ,
                         'ObjButton(OBJECTHANDLE=<WP_4OS2WIN>),'       || ,
                         'ObjButton(OBJECTHANDLE=<WP_4OS2FS>),'        || ,
                         'ObjButton(OBJECTHANDLE=<WP_OS2WIN>),'        || ,
                         'ObjButton(OBJECTHANDLE=<TSPF>),'             || ,
                         'ObjButton(OBJECTHANDLE=<FIREFOXEXE>),'       || ,
                         'ObjButton(OBJECTHANDLE=<THUNDERBEXE>),'      || ,
                         'ObjButton(OBJECTHANDLE=<FileStar2>),'        || ,
                         'ObjButton(OBJECTHANDLE=<WP_HINCHARGESFF>),'  || ,
                         'ObjButton(OBJECTHANDLE=<WP_ASSISTANCE>);'    || ,
              'ALWAYSONTOP=YES;'                                       || ,
              'REDUCEDESKTOP=YES;'
call SetObjectData

say 'Arrange widgets on XCenter'


return

CopyObject:
   Say Copies('ª',75)
   Say 'Copying' Object 'to' Location
   stat = SysCopyObject(Object,Location)
   if stat \= 1 then
      Say 'SysCopyObject returned ' stat
   Return stat

CreateObject:
   Say Copies('ª',75)
   Say 'Creating' Title 'at' location 'as' Class
   prompts=arg(1,A)
   do prompt over prompts
      say prompt
      end
   stat = SysCreateObject(Class,Title,Location,SetupString,'fail')
   if stat \= 1 then
      Say 'SysCreateObject returned ' stat
   Return stat

CreateShadow:
   Say Copies('ª',75)
   Say 'Creating shadow of' Object 'in' Location
   stat = SysCreateShadow(Object,Location)
   if stat \= 1 then
      Say 'SysCreateShadow returned ' stat
   Return stat

SetObjectData:
   Say Copies('ª',75)
   Say 'Updating WPS data of' Object 'with' SetupString
   prompts=arg(1,A)
   do prompt over prompts
      say prompt
      end
   stat = SysSetObjectData(Object,SetupString)
   if stat \= 1 then
      Say 'SysSetObjectData returned ' stat
   Return stat


pause:
   prompts=arg(1,A)
   do prompt over prompts
      say prompt
      end
say 'Hit enter to continue'
parse pull
return

whoops:
C = condition(o)
say 'ADDITIONAL  =' C['ADDITIONAL']
say 'DESCRIPTION =' C['DESCRIPTION']
say 'INSTRUCTION =' C['INSTRUCTION']
say 'CONDITION   =' C['CONDITION']
say 'RESULT      =' C['RESULT']
say 'RC          =' C['RC']
say 'CODE        =' C['CODE']
say 'ERRORTEXT   =' C['ERRORTEXT']
say 'MESSAGE     =' C['MESSAGE']
say 'POSITION    =' C['POSITION']
say 'PROGRAM     =' C['PROGRAM']
say ''
say 'Traceback:'
do T over C['TRACEBACK']
   say '   'T
   end
say ''
say 'PROPAGATED  =' C['PROPAGATED']
return
