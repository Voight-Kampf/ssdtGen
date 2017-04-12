#!/bin/bash
#
# Script (ssdtGen.sh) to create SSDTs for Mac OS.
#
# Version 0.1.2beta - Copyright (c) 2017 by M.F.C.
#
# Introduction:
#     - ssdtGen is an automated bash script that attempts to build and
#        compile SSDTs for X99/Z170 systems running Mac OS!
#     - Simply run the commands in the README to download and execute the
#        ssdtGen.sh file from your Desktop.
#
#
# Bugs:
#     - Bug reports can be filed at: https://github.com/mattcarlotta/ssdtGen/issues
#        Please provide clear steps to reproduce the bug and the output of the
#        script. Thank you!
#

#===============================================================================##
## GLOBAL VARIABLES #
##==============================================================================##

# Debug output path
dPath="$HOME/Desktop/debug_output.txt"

# User's home dir
gPath="$HOME/Desktop"

#DSDT external device path
gExtDSDTPath='_SB_.PCI0'

#SSDT's standard device path
gSSDTPath='_SB.PCI0'

#SSDT being built/compile set by printHeader
gSSDT=""

#SSDT's Table ID set by printHeader
gSSDTID=""

#Currently logged in user
gUSER=$(stat -f%Su /dev/console)

#IASL root compiler directory
gIaslRootDir="/usr/bin/iasl"

#IASL local  directory
gUsrLocalDir="/usr/local/bin"

#IASL local compiler directory
gIaslLocalDir="/usr/local/bin/iasl"

# Github IASL download
gIaslGithub="https://raw.githubusercontent.com/mattcarlotta/ssdtGen/master/tools/iasl"

#Count to cycle thru arrays
gCount=0

# Bold text
bold=$(tput bold)

# Normal text
normal=$(tput sgr0)

#SSDT Table-ID array
gTableID=""

gMoboID=('X99' 'Z170' 'MAXIMUS')

#carriage return
cr=`echo $'\n.'`
cr=${cr%.}

# set Terminal window size
printf '\e[8;30;102t'

# if user ctrl+c, then cleanup
trap '{ _clean_up; exit 1; }' INT

#===============================================================================##
## PRINT CLEANUP DOTS #
##==============================================================================##
function _printDots()
{
  local let dots=0

  while [[ $dots -lt 3 ]]
  do
    ((dots++))
    sleep 0.150
    printf "."
  done

 sleep 0.200
}

#===============================================================================##
## USER ABORTS SCRIPT #
##==============================================================================##
function _clean_up()
{
  clear
  printf "Cleaning up any left-overs"
  _printDots
  rm "${gPath}"/*.dsl 2> /dev/null
  clear
  printf "Script was aborted!\033[0K\r\n"
  exit -0
}

#===============================================================================##
## DISPLAY INSTRUCTIONS #
##==============================================================================##
function display_instructions()
{
  printf "\n"
  printf "To build and compile all SSDTS, input ${bold}buildall${normal} or ${bold}BUILDALL${normal}\n"
  printf "\n"
  printf "To build and compile one SSDT, input ${bold}build NAME${normal} or ${bold}BUILD NAME${normal}:\n"
  printf "\n"
  printf "         ${bold}x99/z170${normal}\n"
  printf "         ${bold}---------${normal}\n"
  printf "       - ${bold}ALZA/HDAS${normal}: Adds x99/z170 support for Realtek on-board sound\n"
  printf "       - ${bold}EVSS${normal}: Adds x99 support for a third PCH sSata controller for IDE, AHCI, RAID storage drives\n"
  printf "          (for up to 6Gb/s transfers)\n"
  printf "       - ${bold}GFX1${normal}: Adds x99/z170 support for a single Nvidia graphics card and adds HDMI audio support\n"
  printf "          for the card as well \n"
  printf "       - ${bold}GLAN${normal}: Adds x99/z170 support for an Intel ethernet controller\n"
  printf "       - ${bold}HECI${normal}: Intel Management Engine Interface that, in general, adds support for various tasks\n"
  printf "           while the system is booting, running or sleeping\n"
  printf "       - ${bold}NVME${normal}: Adds x99/z170 support for a single NVMe drive (MUST be used in conjuction with Rehabman's\n"
  printf "           spoofed HackrNVMeFamily-10_xx_x.kext)\n"
  printf "       - ${bold}LPC0/LPCB${normal}: Adds x99/z170 support to AppleLPC.kext for Low Pin Count devices to connect\n"
  printf "          to the CPU\n"
  printf "       - ${bold}SAT1/SAT0${normal}: Adds x99/z170 support for the PCH SATA controller for SATA devices via Legacy\n"
  printf "          or AHCI mode (for up to 6Gb/s transfers)\n"
  printf "       - ${bold}SMBS/SBUS${normal}: Adds x99/z170 support for a SMBus controller that allows communication between\n"
  printf "          external hardware devices (for example, Apple's Mikey driver)\n"
  printf "       - ${bold}XHC${normal}: Adds power options for the USB xHC Host Controller\n"
  printf "       - ${bold}XOSI${normal}: Adds Windows simulated support for DSDT OSI_ methods\n"
  printf "\n"
  printf "To debug the script, input ${bold}debug${normal} or ${bold}DEBUG${normal}:\n"
  printf "       - Will automatically attempt to build and compile all SSDTS while\n"
  printf "          generating a debug ouput.txt file to the Desktop\n"
  printf "\n"
  while true; do
    read -p "Would you like to reload the script now? (y/n)? " choice
    case "$choice" in
      y|Y )
        main
        break
      ;;
      n|N )
        echo ''
        _clean_up
        break
      ;;
      * )
        printf "${bold}*—-ERROR—-*${normal} That was not a valid option, please try again!\n"
      ;;
    esac
  done
}


#===============================================================================##
## CHECK SIP #
##==============================================================================##
function _getSIPStat()
{
  case "$(/usr/bin/csrutil status)" in
    "System Integrity Protection status: enabled." )
      printf "${bold}*—-WARNING--*${normal} S.I.P is enabled...\n"
      printf "Its recommended (not required) that you completely disable S.I.P. by setting CsrActiveConfig to 0x67 in your config.plist!\n"
      ;;

    *"Filesystem Protections: enabled"* )
      printf "${bold}*—-WARNING--*${normal} S.I.P. is partially disabled, but file system protection is still enabled...\n"
      printf "It/s recommended (not required) that you completely disable S.I.P. by setting CsrActiveConfig to 0x67 in your config.plist!\n"
      ;;

    * )
      ;;
  esac
}

#===============================================================================##
## CHECK MACIASL AND IASL ARE INSTALLED #
##==============================================================================##
function _checkPreInstalled()
{
  if [ -f "$gIaslRootDir" ] || [ -f "$gIaslLocalDir" ];
    then
      echo 'IASL64 is already installed!' > /dev/null 2>&1
    else
      printf "${bold}*—-ERROR—-*${normal} IASL64 isn't installed in the either $gIaslRootDir nor your $gIaslLocalDir directory!\n"
      printf " \n"
      printf "Attempting to download IASL from Github...\n"
      if [ ! -d "$gUsrLocalDir" ];
        then
          echo "$gUsrLocalDir doesn't exist. Creating directory!"
          mkdir -p $gUsrLocalDir
        else
          echo "$gUsrLocalDir already exists" > /dev/null 2>&1
      fi
      curl -o $gIaslLocalDir $gIaslGithub
      if [[ $? -ne 0 ]];
        then
          printf ' \n'
          printf "${bold}*—-ERROR—-*${normal} Make sure your network connection is active!\n"
          exit 1
      fi
      chmod +x $gIaslLocalDir
      printf " \n"
      printf "MaciASL has been installed!\n"
      printf " \n"
  fi
}

#===============================================================================##
## CHECK DEVICE PROP IS NOT EMPTY #
##==============================================================================##
function _checkDevice_Prop()
{
  SSDT_VALUE=$1
  SSDT_DEVICE=$2
  SSDT_PROP=$3

  if [ -z "$SSDT_VALUE" ]
    then
      echo ''
      echo "${bold}*—-ERROR—-*${normal} There was a problem locating $SSDT_DEVICE's $SSDT_PROP!"
      echo "Please run this script in debug mode to generate a debug text file."
      echo ''
      #_clean_up
  fi
}

#===============================================================================##
## EOF BRACKETS #
##==============================================================================##
function _close_Brackets()
{
  local MB=$1
  if [ "$MB" = true ];
    then
    echo '        }'                                                                      >> "$gSSDT"
    echo '    }'                                                                          >> "$gSSDT"
    if [ ! -z "$BRIDGEADDRESS" ];
      then
        echo '    }'                                                                      >> "$gSSDT"
    fi
  else
    echo '            })'                                                                 >> "$gSSDT"
    echo '        }'                                                                      >> "$gSSDT"
    echo '    }'                                                                          >> "$gSSDT"
  fi
}

#===============================================================================##
## SET DEVICE PROPS #
##==============================================================================##
function _setDevice_BufferZero()
{
  echo '                Buffer() { 0x00 },'                                               >> "$gSSDT"
}

#===============================================================================##
## SET DEVICE PROPS #
##==============================================================================##
function _setDevice_NoBuffer()
{
  PROP=$1
  VALUE=$2

  echo '                '$PROP','                                                         >> "$gSSDT"
  echo '                '$VALUE','                                                        >> "$gSSDT"
}

#===============================================================================##
## SET DEVICE PROPS #
##==============================================================================##
function _setDeviceProp()
{
  PROP=$1
  VALUE=$2

  echo '                '$PROP', Buffer() {'$VALUE'},'                                    >> "$gSSDT"

}

#===============================================================================##
## FIND DEVICE PROP #
##==============================================================================##
function _findDeviceProp()
{
  PROP=$1
  local PROP2=$2
  if [ ! -z "$PROP2" ];
    then
      if [[ "$PROP2" == 'GPU' ]];
        then
          SSDT_VALUE=$(ioreg -lw0 -p IODeviceTree -n $PCISLOT -r | grep device-id | tail -n 1 | sed -e 's/ *[",|=:/_@<>-]//g; s/deviceid//g')
        else
          SSDT_VALUE=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP2 | grep $PROP2 |  sed -e 's/ *["|=:/_@]//g; s/'$PROP2'//g')
      fi
    else
      SSDT_VALUE=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP | grep $PROP |  sed -e 's/ *["|=<A-Z>:/_@]//g; s/'$PROP'//g')
  fi

  _checkDevice_Prop "${SSDT_VALUE}" "$DEVICE" "$PROP"

  echo '                "'$PROP'", Buffer() {'                                            >> "$gSSDT"

  if [[ "$PROP" == 'compatible' ]];
    then
      echo '                    "'$SSDT_VALUE'"'                                          >> "$gSSDT"
    elif [[ "$PROP" == 'device-id' ]] || [[ "$PROP" == 'subsystem-vendor-id' ]];
    then
      echo '                    0x'${SSDT_VALUE:0:2}', 0x'${SSDT_VALUE:2:2}', 0x00, 0x00' >> "$gSSDT"
    else
      echo '                    0x00, 0x'${SSDT_VALUE:2:2}', 0x00, 0x00'                  >> "$gSSDT"
  fi
  echo '                },'                                                               >> "$gSSDT"
}

#===============================================================================##
## SET DEVICE STATUS #
##==============================================================================##
function _setGPUDevice_Status()
{
  if [[ "$moboID" = "X99" ]];
    then
      D0XX=$(ioreg -p IODeviceTree -n ${PCISLOT} -r | grep D0 | sed -e 's/ *["+|=<a-z>:/_@-]//g; s/^ *//g')
      D0XX=${D0XX:0:4}

      _checkDevice_Prop "${D0XX}" "$PCISLOT" "D0XX device"

      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${GPU}'._STA, Zero)  // _STA: Status'  >> "$gSSDT"
      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${AUDIO}'._STA, Zero)  // _STA: Status'>> "$gSSDT"
      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${D0XX}'._STA, Zero)  // _STA: Status' >> "$gSSDT"
      echo '}'                                                                            >> "$gSSDT"
    else
      echo '    Name ('${gSSDTPath}'.'${PCISLOT}'.'${GPU}'._STA, Zero)  // _STA: Status'  >> "$gSSDT"
      echo '}'                                                                            >> "$gSSDT"
  fi
}

#===============================================================================##
## SET DEVICE STATUS #
##==============================================================================##
function _setDevice_Status()
{
  echo '    Name ('${gSSDTPath}'.'$SSDT'._STA, Zero)  // _STA: Status'                    >> "$gSSDT"
  echo '}'                                                                                >> "$gSSDT"
}

#===============================================================================##
## GRAB LEqual or LNot _DSM #
##==============================================================================##
function _getDSM()
{
  local DSM=$1

  if [ "$DSM" = true ];
    then
      echo '            If (!Arg2) { Return (Buffer() { 0x03 } ) }'                       >> "$gSSDT"
    else
      echo '        Method (_DSM, 4, NotSerialized)'                                      >> "$gSSDT"
      echo '        {'                                                                    >> "$gSSDT"
      echo '            If (LEqual (Arg2, Zero)) { Return (Buffer() { 0x03 } ) }'         >> "$gSSDT"
  fi
  echo '            Return (Package ()'                                                   >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
}

#===============================================================================##
## FIND AUDIO PROPS #
##==============================================================================##
function _findAUDIO()
{
  if [[ "$moboID" = "X99" ]];
    then
      DEVICE="${DEVICE:0:3}1"
      AUDIO=$DEVICE
  fi

  echo '    Device ('${gSSDTPath}'.'${PCISLOT}'.HDAU)'                                    >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, One)  // _ADR: Address'                                       >> "$gSSDT"
  _getDSM
}


#===============================================================================##
## FIND GPU PROPS #
##==============================================================================##
function _findGPU()
{
  PROP='attached-gpu-control-path'
  GPUPATH=$(ioreg -l | grep $PROP | sed -e 's/ *[",|=:<a-z>/_@-]//g; s/IOSAACPIPEPCI00AACPIPCI//g; s/3IOPP//g; s/0NVDADC2NVDAAGPM//g')
  PCISLOT=${GPUPATH:0:4} #BR3A / PEG0
  DEVICE=${GPUPATH:4:4} #H000 / PEGP
  GPU=$DEVICE

  _checkDevice_Prop "${GPUPATH}" "$SSDT" "$PROP"

  echo '    Device ('${gSSDTPath}'.'${PCISLOT}'.'${SSDT}')'                               >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, Zero)  // _ADR: Address'                                      >> "$gSSDT"
  _getDSM
}

 #===============================================================================##
 ## GRAB WINDOWS OSI  #
 ##==============================================================================##
function _getWindows_OSI()
{
  echo '    Method (XOSI, 1)'                                                             >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Store(Package()'                                                          >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"
  echo '            "Windows",                // generic Windows query'                   >> "$gSSDT"
  echo '            "Windows 2001",           // Windows XP'                              >> "$gSSDT"
  echo '            "Windows 2001 SP2",       // Windows XP SP2'                          >> "$gSSDT"
  echo '             //"Windows 2001.1",      // Windows Server 2003'                     >> "$gSSDT"
  echo '            //"Windows 2001.1 SP1",   // Windows Server 2003 SP1'                 >> "$gSSDT"
  echo '            "Windows 2006",           // Windows Vista'                           >> "$gSSDT"
  echo '            "Windows 2006 SP1",       // Windows Vista SP1'                       >> "$gSSDT"
  echo '            //"Windows 2006.1",       // Windows Server 2008'                     >> "$gSSDT"
  echo '            "Windows 2009",           // Windows 7/Windows Server 2008 R2'        >> "$gSSDT"
  echo '            "Windows 2012",           // Windows 8/Windows Server 2012'           >> "$gSSDT"
  echo '            //"Windows 2013",         // Windows 8.1/Windows Server 2012 R2'      >> "$gSSDT"
  echo '            "Windows 2015",           // Windows 10/Windows Server TP'            >> "$gSSDT"
  echo '        }, Local0)'                                                               >> "$gSSDT"
  echo '       Return (Ones != Match(Local0, MEQ, Arg0, MTR, 0, 0))'                      >> "$gSSDT"
  echo '    }'                                                                            >> "$gSSDT"
  echo '}'                                                                                >> "$gSSDT"
}

#===============================================================================##
## FIND SMBS DEVICE  #
##==============================================================================##
function _findDevice_Address()
{
  DEVICE=$1
  DEVICE2=$2
  PROP='acpi-path'
  SSDTADR=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP | grep $PROP |  sed -e 's/ *["|=<A-Z>:/_@-]//g; s/acpipathlane//g; y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')
  _checkDevice_Prop "${SSDTADR}" "$DEVICE" "$PROP"

  echo '    Device ('${gSSDTPath}'.'${DEVICE2}')'                                         >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, 0x'${SSDTADR}')  // _ADR: Address'                            >> "$gSSDT"
  echo '        Device (BUS0)'                                                            >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"
  echo '            Name (_CID, "smbus") // _CID: Compatible ID'                          >> "$gSSDT"
  echo '            Name (_ADR, Zero)'                                                    >> "$gSSDT"
  echo '            Device (MKY0)'                                                        >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
  echo '                   Name (_ADR, Zero)'                                             >> "$gSSDT"
  echo '                   Name (_CID, "mikey")'                                          >> "$gSSDT"
  _getDSM
  echo '                          "refnum",'                                              >> "$gSSDT"
  echo '                          Zero,'                                                  >> "$gSSDT"
  echo '                          "address",'                                             >> "$gSSDT"
  echo '                          0x39,'                                                  >> "$gSSDT"
  echo '                          "device-id",'                                           >> "$gSSDT"
  echo '                          0x0CCB,'                                                >> "$gSSDT"
  _setDevice_BufferZero
  echo '                      })'                                                         >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (H1EN, 1, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        If (LLessEqual (Arg0, One))'                              >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            If (LEqual (Arg0, One)) { Or (GL04, 0x04, GL04) }'    >> "$gSSDT"
  echo '                            Else { And (GL04, 0xFB, GL04) }'                      >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (H1IL, 0, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        ShiftRight (And (GL00, 0x02), One, Local0)'               >> "$gSSDT"
  echo '                        Return (Local0)'                                          >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (H1IP, 1, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        Store (Arg0, Local0)'                                     >> "$gSSDT"
  echo '                        If (LLessEqual (Arg0, One))'                              >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            Not (Arg0, Arg0)'                                     >> "$gSSDT"
  echo '                            Store (Arg0, GI01)'                                   >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Name (H1IN, 0x11)'                                             >> "$gSSDT"
  echo '                   Scope (\_GPE)'                                                 >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        Method (_L11, 0, NotSerialized)'                          >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            Notify (\_SB.PCI0.SBUS.BUS0.MKY0, 0x80)'              >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (P1IL, 0, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        ShiftRight (And (GL00, 0x40), 0x06, Local0)'              >> "$gSSDT"
  echo '                        Return (Local0)'                                          >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Method (P1IP, 1, Serialized)'                                  >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        If (LLessEqual (Arg0, One))'                              >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            Not (Arg0, Arg0)'                                     >> "$gSSDT"
  echo '                            Store (Arg0, GI06)'                                   >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '                   Name (P1IN, 0x16)'                                             >> "$gSSDT"
  echo '                   Scope (\_GPE)'                                                 >> "$gSSDT"
  echo '                   {'                                                             >> "$gSSDT"
  echo '                        Method (_L16, 0, NotSerialized)'                          >> "$gSSDT"
  echo '                        {'                                                        >> "$gSSDT"
  echo '                            XOr (GI06, One, GI06)'                                >> "$gSSDT"
  echo '                            Notify (\_SB.PCI0.SBUS.BUS0.MKY0, 0x80)'              >> "$gSSDT"
  echo '                        }'                                                        >> "$gSSDT"
  echo '                   }'                                                             >> "$gSSDT"
  echo '            }'                                                                    >> "$gSSDT"
  echo '            Device (DVL0)'                                                        >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
  echo '                Name (_ADR, 0x57)'                                                >> "$gSSDT"
  echo '                Name (_CID, "diagsvault")'                                        >> "$gSSDT"
  _getDSM
  echo '                        "address",'                                               >> "$gSSDT"
  echo '                        0x57,'                                                    >> "$gSSDT"
  _setDevice_BufferZero
  _close_Brackets
  echo '            Device (BLC0)'                                                        >> "$gSSDT"
  echo '            {'                                                                    >> "$gSSDT"
  echo '                Name (_ADR, Zero)'                                                >> "$gSSDT"
  echo '                Name (_CID, "smbus-blc")'                                         >> "$gSSDT"
  _getDSM
  echo '                        "refnum",'                                                >> "$gSSDT"
  echo '                        Zero,'                                                    >> "$gSSDT"
  echo '                        "version",'                                               >> "$gSSDT"
  echo '                        0x02,'                                                    >> "$gSSDT"
  echo '                        "fault-off",'                                             >> "$gSSDT"
  echo '                        0x03,'                                                    >> "$gSSDT"
  echo '                        "fault-len",'                                             >> "$gSSDT"
  echo '                        0x04,'                                                    >> "$gSSDT"
  echo '                        "skey",'                                                  >> "$gSSDT"
  echo '                        0x4C445342,'                                              >> "$gSSDT"
  echo '                        "type",'                                                  >> "$gSSDT"
  echo '                        0x49324300,'                                              >> "$gSSDT"
  echo '                        "smask",'                                                 >> "$gSSDT"
  echo '                        0xFF,'                                                    >> "$gSSDT"
  _close_Brackets
  echo '        }'                                                                        >> "$gSSDT"
  echo '        Device (BUS1)'                                                            >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"
  echo '            Name (_CID, "smbus")'                                                 >> "$gSSDT"
  echo '            Name (_ADR, One)'                                                     >> "$gSSDT"
  echo '        }'                                                                        >> "$gSSDT"
  echo '    }'                                                                            >> "$gSSDT"
  echo '    OperationRegion (GPIO, SystemIO, 0x0500, 0x3C)'                               >> "$gSSDT"
  echo '    Field (GPIO, ByteAcc, NoLock, Preserve)'                                      >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Offset (0x0C),'                                                           >> "$gSSDT"
  echo '        GL00,   8,'                                                               >> "$gSSDT"
  echo '            ,   1,'                                                               >> "$gSSDT"
  echo '        GI01,   1,'                                                               >> "$gSSDT"
  echo '            ,   1,'                                                               >> "$gSSDT"
  echo '        GI06,   1,'                                                               >> "$gSSDT"
  echo '        Offset (0x2D),'                                                           >> "$gSSDT"
  echo '        GL04,   8'                                                                >> "$gSSDT"
  echo '    }'                                                                            >> "$gSSDT"
}

#===============================================================================##
## GET EXTERNAL DEVICE NVME DEVICE #
##==============================================================================##
function _getExtDevice_NVME
{
  # DEVICE (BR1B)
  echo '    External ('${gExtDSDTPath}'.'${NVMEDEVICE}', DeviceObj)'                      >> "$gSSDT"
  FOUNDD0xx=$(ioreg -p IODeviceTree -n "$NVMEDEVICE" -r | grep D0 | sed -e 's/ *["+|=<a-z>:/_@-]//g; s/^ *//g' | cut -c1-4 | sed '$!N;s/\n/ /')

  if [ -z "$INCOMPLETENVMEPATH" ];
    then
      #BR1B.H000, BR1B.D075, BR1B.D081
      extDEVICES=($NVMELEAFNODE $FOUNDD0xx)
    else
      extDEVICES=($FOUNDD0xx)
  fi

  for((i=0;i<${#extDEVICES[@]};i++))
  do
    echo '    External ('${gExtDSDTPath}'.'${NVMEDEVICE}'.'${extDEVICES[$i]}', DeviceObj)'>> "$gSSDT"
    echo '    Scope ('${gExtDSDTPath}'.'${NVMEDEVICE}'.'${extDEVICES[$i]}')'              >> "$gSSDT"
    echo '    {Name (_STA, Zero)}'      >> "$gSSDT"
  done
  echo '    Scope ('${gExtDSDTPath}'.'${NVMEDEVICE}')'                                    >> "$gSSDT"
  echo '    {'                          >> "$gSSDT"
  echo '        Device (NVME)'                                                            >> "$gSSDT"
  echo '        {'                                                                        >> "$gSSDT"

  if [ -z "$INCOMPLETENVMEPATH" ];
    then
      #NVME HAS COMPLETE ACPI
      echo '            Name (_ADR, Zero)'                                                >> "$gSSDT"
    else
      #NVME HAS INCOMPLETE ACPI
        echo '            Name (_ADR, '$NVME_ACPI_ADRESSS')'                              >> "$gSSDT"
  fi

  if [ ! -z "$BRIDGEADDRESS" ]
    then
    echo '        Device (PCIB)'                                                          >> "$gSSDT"
    echo '        {'                                                                      >> "$gSSDT"
    echo '            Name (_ADR, '$BRIDGEADDRESS')'                                      >> "$gSSDT"
  fi

  _getDSM
}

#===============================================================================##
## GRAB EXTERNAL DEVICE ADDRESS #
##==============================================================================##
function _getExtDevice_Address()
{
  DEVICE=$1

  echo '    External ('${gExtDSDTPath}'.'${DEVICE}', DeviceObj)'                          >> "$gSSDT"
  echo '    Method ('${gSSDTPath}'.'${DEVICE}'._DSM, 4, NotSerialized)'                   >> "$gSSDT"
  echo '    {'                                                                            >> "$gSSDT"
  _getDSM true
}

#===============================================================================##
## GRAB DEVICE ADDRESS #
##==============================================================================##
function _getDevice_ACPI_Path()
{
  DEVICE=$1
  NEWDEVICE=$2
  PROP='acpi-path'
  SSDTADR=$(ioreg -p IODeviceTree -n "$DEVICE" -k $PROP | grep $PROP |  sed -e 's/ *["|=<A-Z>:/_@-]//g; s/acpipathlane//g; y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')
  _checkDevice_Prop "${SSDTADR}" "$DEVICE" "$PROP"

  if [ ! -z "$NEWDEVICE" ];
    then
      echo '    Device ('${gSSDTPath}'.'${NEWDEVICE}')'                                   >> "$gSSDT"
    else
      echo '    Device ('${gSSDTPath}'.'${DEVICE}')'                                      >> "$gSSDT"
  fi
  echo '    {'                                                                            >> "$gSSDT"
  echo '        Name (_ADR, 0x'${SSDTADR}')  // _ADR: Address'                            >> "$gSSDT"
  _getDSM
}

#===============================================================================##
## CHECKS WHAT KIND OF METHOD: DSM OR DEVICE #
##==============================================================================##
function _buildSSDT()
{
  SSDT=$1

  if [ "$SSDT" == "ALZA" ] || [ "$SSDT" == "HDAS" ];
    then
      # for debug only
      #_getDevice_ACPI_Path "HDEF"
      # for debug only
      _getDevice_ACPI_Path "${SSDT}" "HDEF"
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"device_type"' '"Audio Controller"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"model"' '"Realtek Audio Controller"'
      _setDeviceProp '"hda-gfx"' '"onboard-1"'
      _setDeviceProp '"layout-id"' '0x01, 0x00, 0x00, 0x00'
      _setDeviceProp '"PinConfigurations"' '0x00'
      _findDeviceProp 'compatible' 'IOName'
      _close_Brackets
      _setDevice_Status
  fi

  if [[ "$SSDT" == "EVSS" ]];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"name"' '"Intel sSata Controller"'
      _setDeviceProp '"model"' '"Intel 99 Series Chipset Family sSATA Controller"'
      _setDeviceProp '"device_type"' '"AHCI Controller"'
      _findDeviceProp 'compatible' 'IOName'
      _findDeviceProp 'device-id'
      _close_Brackets
  fi

  if [[ "$SSDT" == "GFX1" ]];
    then
      _findGPU
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"hda-gfx"' '"onboard-2"'
      _setDeviceProp '"@0,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@1,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@2,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@3,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@4,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _setDeviceProp '"@5,connector-type"' '0x00, 0x08, 0x00, 0x00'
      _close_Brackets
      _findAUDIO
      _setDeviceProp '"hda-gfx"' '"onboard-2"'
      _setDeviceProp '"PinConfigurations"' '0xe0, 0x00, 0x56, 0x28'
      _findDeviceProp 'device-id' 'GPU'
      _close_Brackets
      _setGPUDevice_Status
  fi

  if [[ "$SSDT" == "GLAN" ]];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"model"' '"Intel i219V"'
        else
          _setDeviceProp '"model"' '"Intel i218V"'
      fi
      _setDeviceProp '"name"' '"Ethernet Controller"'
      _setDeviceProp '"built-in"' '0x00'
      _findDeviceProp 'device-id'
      _findDeviceProp 'subsystem-id'
      _findDeviceProp 'subsystem-vendor-id'
      _close_Brackets
  fi

  if [[ "$SSDT" == "HECI" ]];
    then
      # for debug only
      #_getDevice_ACPI_Path "IMEI"
      # for debug only
      _getDevice_ACPI_Path "${SSDT}" "IMEI"
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"name"' '"IMEI Controller"'
      _setDeviceProp '"model"' '"IMEI Controller"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"compatible"' '"pci8086,1e3a"'
      _setDeviceProp '"device-id"' '0x3A, 0x1E, 0x00, 0x00'
      _close_Brackets
      _setDevice_Status
  fi

  if [[ "$SSDT" == "NVME" ]];
    then
      _getExtDevice_NVME "${NVME_ACPI_PATH}"
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"name"' '"NVMe Controller"'
      _setDeviceProp '"model"' '"NVMe Controller"'
      _setDeviceProp '"class-code"' '0xFF, 0x08, 0x01, 0x00'
      _setDeviceProp '"built-in"' '0x00'
      _close_Brackets
      _close_Brackets true
  fi

  if [ "$SSDT" == "LPC0" ] || [ "$SSDT" == "LCPB" ];
    then
      _getExtDevice_Address $SSDT
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"compatible"' '"pci8086,9cc1"'
        else
          _setDeviceProp '"compatible"' '"pci8086,9c43"'
      fi

      _close_Brackets
  fi

  if [ "$SSDT" == "SAT1" ] || [ "$SSDT" == "SAT0" ];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"built-in"' '0x00'
      _setDeviceProp '"device-type"' '"AHCI Controller"'
      _setDeviceProp '"name"' '"Intel AHCI Controller"'
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"model"' '"Intel 10 Series Chipset Family SATA Controller"'
        else
          _setDeviceProp '"model"' '"Intel 99 Series Chipset Family SATA Controller"'
      fi

      _findDeviceProp 'compatible' 'IOName'
      _findDeviceProp 'device-id'
      _close_Brackets
  fi

  if [ "$SSDT" == "SMBS" ] || [ "$SSDT" == "SBUS" ];
    then
      if [[ "$moboID" = "Z170" ]];
        then
          _findDevice_Address "${SSDT}" "SMBS"
        else
          # for debug only
          #_findDevice_Address SBUS "SBUS"
          # for debug only
          _findDevice_Address "${SSDT}" "SBUS"
      fi
      _setDevice_Status
  fi

  if [[ "$SSDT" == "XHC" ]];
    then
      _getExtDevice_Address $SSDT
      _setDeviceProp '"AAPL,slot-name"' '"Built In"'
      _setDeviceProp '"name"' '"Intel XHC Controller"'
      if [[ "$moboID" = "Z170" ]];
        then
          _setDeviceProp '"model"' '"Intel 10 Series Chipset Family USB xHC Host Controller"'
        else
          _setDeviceProp '"model"' '"Intel 99 Series Chipset Family USB xHC Host Controller"'
      fi
      _setDevice_NoBuffer '"AAPL,current-available"' '0x0834'
      _setDevice_NoBuffer '"AAPL,current-extra"' '0x0A8C'
      _setDevice_NoBuffer '"AAPL,current-in-sleep"' '0x0A8C'
      _setDevice_NoBuffer '"AAPL,max-port-current-in-sleep"' '0x0834'
      _setDevice_NoBuffer '"AAPL,device-internal"' '0x00'
      _setDevice_BufferZero
      _setDeviceProp '"AAPL,clock-id"' '0x01'
      _findDeviceProp 'device-id'
      _close_Brackets
  fi

  if [[ "$SSDT" == "XOSI" ]];
    then
      _getWindows_OSI
  fi
}

##===============================================================================##
# COMPILE SSDT AND CLEAN UP #
##===============================================================================##
function _compileSSDT
{
  ((gCount++))
  chown $gUSER $gSSDT
  printf "${STYLE_BOLD}Compiling:${STYLE_RESET} ${gSSDTID}.dsl\n"
  iasl -G "$gSSDT"
  printf "${STYLE_BOLD}Removing:${STYLE_RESET} ${gSSDTID}.dsl\n"
  printf  "\n%s" '--------------------------------------------------------------------------------'
  printf '\n'
  rm "$gSSDT"
  if [ ! -z "$buildOne" ];
    then
      echo "User only wanted to build ${buildOne}" > /dev/null 2>&1
      exit 0
  fi
  if [[ $gCount -lt 10 ]];
   then
      echo 'Attempting to build all SSDTs...' > /dev/null 2>&1
     _printHeader
  fi
}

##===============================================================================##
# PRINT FILE HEADER #
##===============================================================================##
function _printHeader()
{
  gSSDTID="SSDT-${gTableID[$gCount]}"
  printf 'Creating: '${gSSDTID}'.dsl \n'
  gSSDT="${gPath}/${gSSDTID}.dsl"

  echo 'DefinitionBlock ("", "SSDT", 1, "mfc88", "'${gTableID[$gCount]}'", 0x00000000)'   > "$gSSDT"
  echo '{'                                                                                >> "$gSSDT"
  _buildSSDT ${gTableID[$gCount]}
  _compileSSDT
}

##===============================================================================##
# CHECK USER CHOICES TO SSDT LIST #
##===============================================================================##
function _checkIf_PATH_Exists()
{
  if [ ! -z "$INCOMPLETENVMEPATH" ];
    then
      IOREGPATH=$(ioreg -p IODeviceTree -n "$NVMEDEVICE" -r)
    else
      IOREGPATH=$(ioreg -p IODeviceTree -n "$NVMEDEVICE" -r | grep -o $NVMELEAFNODE)
  fi

  if [ -z "$IOREGPATH" ]
    then
        if [ -z "$INCOMPLETENVMEPATH" ];
        then
          echo ''
          echo "${bold}*—-ERROR—-*${normal} There was a problem locating $NVMEDEVICE's leafnode ($NVMELEAFNODE)!"
          echo "Please make sure the ACPI path submitted is correct!"
          _askfor_NVMEPATH
        else
          echo ''
          echo "${bold}*—-ERROR—-*${normal} There was a problem locating $INCOMPLETENVMEPATH!"
          echo "Please make sure the ACPI path submitted is correct!"
          _askfor_INCOMPLETENVMEDETAILS
    fi
  fi
}

##===============================================================================##
# CHECK IF USER SPECIFIED ADDRESSES ARE IN CORRECT FORMAT #
##===============================================================================##
function _checkIf_VALIDADRESS()
{
  BR=$1

  if [ "$BR" == true ];
    then
      if [ -z "$BRIDGEADDRESS" ] || [[ "$BRIDGEADDRESS" != 0x* ]];
        then
        echo ''
        echo "${bold}*—-ERROR—-*${normal} You must include a valid address! Try again"
        _askfor_PCIBRIDGE
      fi
    else
      if [ -z "$NVME_ACPI_ADRESSS" ] || [[ "$NVME_ACPI_ADRESSS" != 0x* ]];
        then
        echo ''
        echo "${bold}*—-ERROR—-*${normal} You must include a valid address! Try again"
        _askfor_INCOMPLETENVMEDETAILS
      fi
  fi
}

##===============================================================================##
# ASK USER IF NVME IS BEHIND PCI BRIDGE #
##===============================================================================##
function _askfor_PCIBRIDGE()
{
  echo ''
  while true; do
  read -p "Is the NVME's path behind a PCI bridge? Write ${bold}yes${normal} followed by the PCI bridge address location ${bold}0x0000${normal}, othwerwise write ${bold}no${normal}. $cr--> " choice
    case "$choice" in
      exit|EXIT )
      _clean_up
      break
      ;;
      no|NO )
      echo 'NVME isn/t behind a PCI bridge!' > /dev/null 2>&1
      break
      ;;
      yes*|YES* )
      BRIDGEADDRESS=${choice:4:10}
      _checkIf_VALIDADRESS true
      break
      ;;
      * )
      echo ''
      echo "${bold}*—-ERROR—-*${normal} Sorry, but $choice is not a valid option! Try again"
      echo ''
      ;;
    esac
  done
}

##===============================================================================##
# ASK USER WHERE NVME IS LOCATED #
##===============================================================================##
function _askfor_NVMEPATH()
{
  echo ''
  read -p "What is the NVME's ACPI path? For example, write ${bold}BR1B.H000${normal}, or ${bold}RP04.PSXS${normal}, or ${bold}PEG0.PEGP${normal}, and so on. $cr--> " choice
    case "$choice" in
      exit|EXIT )
      _clean_up
      ;;
      * )
      NVME_ACPI_PATH=$choice
      NVMEDEVICE=${choice:0:4}
      NVMELEAFNODE=${choice:5:4}
      _checkIf_PATH_Exists
      _askfor_PCIBRIDGE
      echo ''
      gCount=$i
      _printHeader
      ;;
  esac
}

##===============================================================================##
# ASK USER IF NVME PATH IS COMPLETE #
##===============================================================================##
function _askfor_INCOMPLETENVMEDETAILS()
{
  echo ''
  read -p "Is the NVME's ACPI path incomplete? If so, write the device and address. For example: ${bold}BR1B 0x0000${normal}, or ${bold}RP04 0x0000${normal}, or ${bold}PEG0 0x0000${normal}, and so on. Otherwise, just write ${bold}no${normal}. $cr--> " choice
    case "$choice" in
      exit|EXIT )
      _clean_up
      ;;
      no|NO )
      echo 'NVME/s ACPI path isn/t incomplete!' > /dev/null 2>&1
      _askfor_NVMEPATH
      ;;
      * )
      NVME_ACPI_PATH=${choice:0:4}
      NVME_ACPI_ADRESSS=${choice:5:10}
      INCOMPLETENVMEPATH=$NVME_ACPI_PATH
      NVMEDEVICE=$NVME_ACPI_PATH
      _checkIf_VALIDADRESS
      _checkIf_PATH_Exists
      echo ''
      gCount=$i
      _printHeader
      ;;
  esac
}

##===============================================================================##
# CHECK USER CHOICES TO SSDT LIST #
##===============================================================================##
function _checkIf_SSDT_Exists()
{
  for((i=0;i<=10;i++))
  do
  if [[ "${buildOne}" == "${gTableID[$i]}" ]];
    then
    if [[ "${buildOne}" == "NVME" ]];
      then
        gCount=$i
        _askfor_INCOMPLETENVMEDETAILS
        exit 0
    fi
    gCount=$i
    echo ''
    _printHeader
    exit 0
  fi
  done

  echo ''
  echo "${bold}*—-ERROR—-*${normal} $buildOne is not a SSDT!"
  display_instructions
}

##===============================================================================##
# USER CHOOSES WHAT TO DO #
##===============================================================================##
function _user_choices()
{
  echo ''
  read -p "build all SSDTs(${bold}buildall${normal}) | build a single SSDT(${bold}build NAME${normal}) | debug(${bold}debug${normal}) | help(${bold}help${normal}) | exit(${bold}exit${normal}) $cr--> " choice
    case "$choice" in
      # attempt to build all SSDTs
      buildall|BUILDALL )
      _checkBoard
      main true
      exit 0
      ;;
      # attempt to build one SSDT
      build* | BUILD*)
      _checkBoard
      buildOne=${choice:6:9}
      _checkIf_SSDT_Exists
      exit 0
      ;;
      # debug mode
      debug|DEBUG )
      set -x
      #main true 2>&1 | tee "$dPath"
      echo 'Now running in debug mode!'
      _user_choices 2>&1 | tee "$dPath"
      ioreg >> "$dPath"
      set +x
      exit 0
      ;;
      # display help instructions
      help|HELP )
      display_instructions
      ;;
      # kill the script
      exit|EXIT )
      _clean_up
      ;;
      # oops - user made a mistake, reload script
      * )
      printf "\n"
      printf "${bold}*—-ERROR—-*${normal} That was not a valid option!"
      printf "\n"
      display_instructions
      ;;
  esac
}

#===============================================================================##
## GREET USER #
##==============================================================================##
function greet()
{
  printf '                         ssdtGen Version 0.1.2b - Copyright (c) 2017 by M.F.C.'
  printf  "\n%s" '-----------------------------------------------------------------------------------------------------'
  printf ' \n'
  sleep 0.25
}

#===============================================================================##
## FIND USER'S MOTHERBOARD #
##==============================================================================##
function _findMoboID()
{
  #moboID=$(ioreg -n FakeSMCKeyStore -k product-name | grep product-name | sed -e 's/ *["|=:/_@-]//g; s/productname//g' | grep -o $mobo)
  moboID=$(ioreg -lw0 -p IODeviceTree | awk '/OEMBoard/ {print $4}' | grep -o ${gMoboID[$i]})
}

#===============================================================================##
## CHECK TO SEE IF USER'S MOTHERBOARD IS SUPPORTED #
##==============================================================================##
function _checkBoard
{
  for((i=0;i<=${#gMoboID[@]};i++))
  do
    _findMoboID
    if [ ! -z "$moboID" ];
      then
        echo "User has a $moboID board!"  > /dev/null 2>&1
        break
    fi
  done

  if [[ "$moboID" = "X99" ]];
    then
      gTableID=('ALZA' 'EVSS' 'GFX1' 'GLAN' 'HECI' 'LPC0' 'SAT1' 'SMBS' 'XHC' 'XOSI' 'NVME')
    elif [[ "$moboID" = "Z170" ]] || [[ "$moboID" = "MAXIMUS" ]];
      then
      gTableID=('EVSS' 'GLAN' 'GFX1' 'HDAS' 'HECI' 'LPCB' 'SAT0' 'SBUS' 'XHC' 'XOSI' 'NVME')
  else
    printf "\n"
    printf "${bold}*—-ERROR—-*${normal} This script only supports X99/Z170 motherboards at the moment!\n"
    printf "\n"
    sleep 1
    printf "Script was aborted!\033[0K\r\n"
    printf "\n"
    exit 0
  fi
}

#===============================================================================##
## START PROGRAM #
##==============================================================================##
function main()
{
  local userChosen=$1

  clear
  greet
  if [ -z "$userChosen" ];
    then
      _user_choices
  fi
  _getSIPStat
  _checkPreInstalled
  _printHeader
}

if [[ `id -u` -ne 0 ]];
  then
    printf "This script must be run as ROOT! Please input your Mac OS password to continue!\n"
    sudo "$0"
  else
    main
    exit 0
fi
