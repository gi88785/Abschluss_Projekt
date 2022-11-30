//////////////////////////////////////////////////////////////////////
///
/// <summary>
/// Hier wird das Menu der EDI Error Scan gebildet
/// </summary>
///
///
/// <remarks>
/// </remarks>
///
///
/// <copyright>
/// stratEDI GmbH, (c) 2022. Alle Rechte vorbehalten.
/// </copyright>
///
//////////////////////////////////////////////////////////////////////

#include "Xbp.ch"
#include "EES.ch"
// Erstellt die Menuleiste
  PROCEDURE MenuCreate( oMenuBar)
   LOCAL oMenu, oDV
   SET CHARSET TO ANSI

   oDV   := DatenVerarbeitung():new()

   oMenu := SubMenuNew( oMenu, "~Datei")

   oMenu:addItem( {"EDI ~Datei öffnen", {|| oDV:NewDocument(oDV:LoadFile())}})
   oMenu:addItem( {"EDI Datei ~prüfen", {|| CheckFile( oDV:cFile, oDV:cFReceiver)}})

   oMenu:addItem( MENUITEM_SEPARATOR)
   oMenu:addItem( {"~Beenden",{|| AppQuit()}})
   oMenuBar:addItem( { oMenu, NIL})

   oMenu := SubMenuNew( oMenu, "~Bearbeiten")
   oMenu:addItem( {"~Neue Zuordnung eintragen", {|| Dummy()}})
   oMenu:addItem( {"~Zuordnung bearbeiten", {|| Dummy()}})
   oMenuBar:addItem({ oMenu, NIL})
RETURN

//"Vereinfacht" die Erstellung von Untermenus
FUNCTION SubMenuNew( oMenu, cTitle)
   LOCAL oSubMenu := XbpMenu():new( oMenu)
      oSubMenu:title := cTitle
RETURN oSubMenu:create()

PROCEDURE Dummy()
 MsgBox("Leider mache ich noch nichts. :(", "Versuch zwecklos...")
RETURN







