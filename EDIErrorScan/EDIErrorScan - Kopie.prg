//////////////////////////////////////////////////////////////////////
//
//  EDI Error Scan.PRG
//
//  Copyright:
//      stratEDI GmbH, (c) 2022. Alle Rechte vorbehalten.
//
//  Inhalt:
//      Main Routine und AppSys() für die EDI ErrorScan
//
//////////////////////////////////////////////////////////////////////

#include "Gra.ch"
#include "Xbp.ch"
#include "AppEvent.ch"
#include "EES.ch"
#include "DelDbe.ch"

PROCEDURE MAIN()
   LOCAL nEvent, mp1, mp2, oXbp
   SET CHARSET TO ANSI

   DO WHILE .T.
    nEvent := AppEvent( @mp1, @mp2, @oXbp)
    oXbp:handleEvent( nEvent, mp1, mp2)
   ENDDO
RETURN

// Routine die das Programm beendet

PROCEDURE AppQuit()
   LOCAL nButton

   nButton := ConfirmBox( , ;
                        "Wollen Sie das Programm beenden?", ;
                        "Programm schließen", ;
                        XBPMB_YESNO, ;
                        XBPMB_QUESTION+XBPMB_APPMODAL+XBPMB_MOVEABLE )

   IF nButton == XBPMB_RET_YES
    CLOSE ALL
    QUIT
   ENDIF
RETURN

PROCEDURE AppSys
   LOCAL oXbpm, aPos[2], aSize
   LOCAL oXbp1, oXbp2, oDV

   PUBLIC cProgPath := CurDir()


   //Fenstergrosse wird auf 80% der Auflosung festgelegt
   aSize    := SetAppWindow():currentSize()
   aPos[1]  := 0.1 * aSize[1]
   aPos[2]  := 0.1 * aSize[2]
   aSize[1] *= 0.8
   aSize[2] *= 0.8

   oDV := Datenverarbeitung():new()

   //Anwendungsfenster erzeugen
   oMain       := XbpDialog():new(,, aPos, aSize,, .F.)
   oMain:title := "EDI Error Scan"
   oMain:close := {||AppQuit()}
   oMain:tasklist :=.T.
   oMain:drawingArea:ClipChildren := .T.
   oMain:drawingArea:DropZone  := .T.
   oMain:drawingArea:DragDrop  := {|aState, oData| oDV:HandleDragDrop( aState, oData)}
   oMain:drawingArea:DragEnter := {|aState, oData| oDV:HandleDragEnter( aState, oData)}
   oMain:drawingArea:DragLeave := {|aState, oData| oDV:HandleDragLeave( aState, oData)}
   oMain:create()
   oMain:drawingArea:SetColorBG( XBPSYSCLR_APPWORKSPACE)
   SetAppWindow( oMain)

   drawingArea := oMain:drawingArea

   MenuCreate( oMain:menuBar())

   oMain:show()
   SetAppFocus( oMain)
RETURN

PROCEDURE CheckFile(cFilePath, cEmpfaenger)
   LOCAL oLogEdit := Datenverarbeitung():new()
   LOCAL cInhaltCodeFile := cPruefdatei := cEmpfGLN := cPruefdatei := cPruefdatei_Pfad := ""
   LOCAL cSrcLw    := lower(SYS5())
   LOCAL a1
//   LOCAL cDbPath   := cSrcLw + "\xbase\cctop\Fehlerscan\EDIErrorScan\run"
//   LOCAL cCodeFile := cSrcLw + "\xbase\cctop\Fehlerscan\EDIErrorScan\run\config.cod"
   LOCAL cDbPath   := cSrcLw  + "\" + cProgPath
   LOCAL cCodeFile := cDbPath + "\config.cod"

   LOCAL cCodeDBf  := cDbPath + "\Prufcode.DBF"

   LOCAL aStructure := { { "GLN"   , "C",   13, 0 }, ;
                         { "Name"  , "C",   30, 0 }, ;
                         { "Dateiname"  , "C",  250, 0 }  }

   IF cFilePath == "" .OR. cFilePath == NIL
      MSGBOX("Öffnen Sie zuerst eine Datei.", "Achtung!")
      RETURN
   ENDIF

   DbCreate(cCodeDBf, aStructure, "DBFDBE")

   SELECT 1
   USE (cCodeDBf) ALIAS a1
   append from (cCodeFile) VIA "DELDBE"
   append blank
   replace a1 -> GLN with "EOF"

   go top
   DO WHILE .not. EOF()
      cEmpfGLN := alltrim(a1 -> GLN)
      IF cEmpfGLN == cEmpfaenger
         cPruefdatei := ALLTRIM(a1 -> Dateiname)
         EXIT
      ENDIF
      SKIP
   ENDDO

   IF cPruefdatei == ""
      MsgBox("Zu der GLN "+ cEmpfaenger + " existiert keine Prüfvorlage.", "Warnung!")
    //  cOk := Unknown_Receiver( cEmpfaenger)
   ELSE
      cPruefdatei_Pfad := cDbPath + "\Vorlagen\" + cPruefdatei
      oLogEdit:NewDocument(RunEDICheck( cFilePath, cPruefdatei_Pfad))
   ENDIF

   DELETE FILE(cCodeDBf)

RETURN

FUNCTION Unknown_Receiver( cUnk_GLN)
   LOCAL nEvent, mp1, mp2, aSize
   LOCAL oDlg, oXbp, oCombo, drawingArea, aEditControls := {}
   LOCAL cAuswahl, aAuswahl := {}
   SET CHARSET TO ANSI
   aSize := {600,300}
   //aPos  :={}

   SELECT 1

//   oDlg := XbpDialog():new( GetApplication():MainForm:DrawingArea, , NIL, aSize, , .F.)
   oDlg := XbpDialog():new(, , NIL, aSize, , .T.)
   oDlg:taskList := .T.
   oDlg:clipChildren := .T.
   oDlg:title := "Vorlage für unbekannten Empfänger"
   oDlg:Close := {|| oDlg:Destroy()}
   oDlg:create()

   drawingArea := oDlg:drawingArea
   drawingArea:setFontCompoundName( "8.Arial" )

   oCombo := XbpCombobox():new( drawingArea, , {80,100}, {424,100}, { { XBP_PP_BGCLR, XBPSYSCLR_ENTRYFIELD } }, .T. )
   oCombo:markMode := XBPLISTBOX_MM_SINGLE
   oCombo:type := XBPCOMBO_DROPDOWNLIST
   oCombo:create()
   oCombo:addItem("Grün")
   oCombo:addItem("Blau")
   oCombo:addItem("Rot")

   oXbp := XbpStatic():new( drawingArea, , {150,200}, {250,16}, { { XBP_PP_BGCLR, -255 } } )
   oXbp:caption := "Prüfvorlage für GLN " + cUnk_GLN + " wählen"
   oXbp:clipSiblings := .T.
   oXbp:options := XBPSTATIC_TEXT_CENTER
   oXbp:create()

   oDlg:show()
   SetAppFocus(oDlg)
RETURN




