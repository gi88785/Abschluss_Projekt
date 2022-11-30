///////////////////////////////////////////////////////////////////////////////
//
//  Vom Xbase++ FormDesigner erstellter Funktions Code
//    Erstellt am: 30.03.2022 Zeit: 14:03:45
//
///////////////////////////////////////////////////////////////////////////////

#include "Gra.ch"
#include "Xbp.ch"
#include "Appevent.ch"
#include "Font.ch"

#PRAGMA LIBRARY( "ascom10.lib" )

PROCEDURE Main
   LOCAL nEvent, mp1, mp2, aSize
   LOCAL oDlg, oXbp, drawingArea, aEditControls := {}

   IF IsMemberVar(XbpDialog(),"ClientSize") == .T.
      aSize := {0,0}
   ELSE
      aSize := {600,317}
   ENDIF
   
   oDlg := XbpDialog():new( AppDesktop(), , {1005,803}, aSize, , .F.)
   IF aSize[1] == 0 .AND. aSize[2] == 0
      oDlg:ClientSize := {584,278}
   ENDIF
   oDlg:taskList := .T.
   oDlg:title := "Neues Formular"
   oDlg:create()

   drawingArea := oDlg:drawingArea
   drawingArea:setFontCompoundName( "8.Arial" )

   oXbp := XbpCombobox():new( drawingArea, , {80,140}, {424,24}, { { XBP_PP_BGCLR, XBPSYSCLR_ENTRYFIELD } } )
   oXbp:type := XBPCOMBO_DROPDOWNLIST
   oXbp:create()

   oXbp := XbpStatic():new( drawingArea, , {184,200}, {188,16}, { { XBP_PP_BGCLR, -255 } } )
   oXbp:caption := "Vorlage w„hlen"
   oXbp:clipSiblings := .T.
   oXbp:options := XBPSTATIC_TEXT_CENTER
   oXbp:create()

   oDlg:show()
   SetAppFocus(oDlg)

   nEvent := xbe_None
   DO WHILE nEvent <> xbeP_Close
      nEvent := AppEvent( @mp1, @mp2, @oXbp )
      oXbp:handleEvent( nEvent, mp1, mp2 )
   ENDDO
RETURN