vide
====

VI for Delphi IDE

Installation
============

- Open the relevant .dproj file for your version of Delphi.
- Select "Release"
- Build the project
- Copy the resulting DLL to your selected install location
- Set the registry entry [HKEY_CURRENT_USER\Software\Embarcadero\BDS\9.0\Experts] to VIDE_XE2="C:\location\VIDE_XE2.dll"

Debugging
==========

- Open the relevant .dproj file for your version of Delphi.
- Select "Release"
- Build the project
- Select Run Parameters and set the Host Application to be the IDE.
- Set the registry entry [HKEY_CURRENT_USER\Software\Embarcadero\BDS\9.0\Experts] to VIDE_XE2="C:\location_of_debug_dll\VIDE_XE2.dll"
- Start Debugging

DON'T FORGET AFTERWARDS TO RESET THE REGISTRY ENTRY TO THE INSTALLED VERSION OF THE DLL.
