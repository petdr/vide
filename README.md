vide
====

VI for Delphi IDE

This package provides a very minimal set of key bindings to allow one to do some vi actions inside the delphi editor.

Installation
============

- Open the relevant .dproj file for your version of Delphi.
- Select "Release"
- Build the project
- Copy the resulting DLL to your selected install location, eg C:\location
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

Updating to a new version of Delphi
===================================

- Create a DLL project and name it VIDE_DELPHIVER.dll
- Edit runtime packages and add designide (No longer required with Berlin and later).
- Check Link runtime packages
